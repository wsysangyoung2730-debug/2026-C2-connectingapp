import Foundation
import Combine
import FirebaseFirestore
import UIKit

/// Firebase is the authority for participants, acceptance and delivered messages.
/// Local storage contains only account-scoped drafts and an idempotent outbox.
@MainActor
final class LiveChatStore: ObservableObject {
    static let shared = LiveChatStore()
    @Published private(set) var profiles: [ChatProfile] = []
    @Published private(set) var rooms: [ChatRoom] = []
    @Published private(set) var messages: [ChatMessage] = []
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var publishedProfile: ChatProfile?
    @Published private(set) var profileLoaded = false
    @Published private(set) var currentUserID: String?
    @Published private(set) var hasOlderMessages = false
    @Published private(set) var hasMoreProfiles = false
    private var database: Firestore?
    private var sessionSubscription: AnyCancellable?
    private var listeners: [ListenerRegistration] = []
    private var roomListeners: [String: [ListenerRegistration]] = [:]
    private var latestListeners: [String: ListenerRegistration] = [:]
    private var messageListener: ListenerRegistration?
    private var generation = UUID()
    private var chatGeneration = UUID()
    private var cache: ChatLocalCache?
    private var roomData: [String: [String: Any]] = [:]
    private var knownProfiles: [String: ChatProfile] = [:]
    private var discoveryIDs = Set<String>()
    private var blockedIDs = Set<String>()
    private var states: [String: [String: Any]] = [:]
    private var latestMessages: [String: ChatMessage] = [:]
    private var remoteMessages: [String: ChatMessage] = [:]
    private var activeRoomID: String?
    private var oldestMessage: DocumentSnapshot?
    private var profileCursor: DocumentSnapshot?
    private var hasLoadedMoreProfiles = false
    private var hasLoadedOlderPage = false
    private var loadingOlder = false
    private var writingRead = Set<String>()
    private var sendingIDs = Set<String>()

    #if DEBUG
    private func loadScreenshotFixtures() {
        publishedProfile = ChatProfile(id: "screenshot-owner", name: "하루", interests: ["러닝", "기록", "산책", "음악", "독서", "사진"])
        profiles = [
            ChatProfile(id: "screenshot-forest", name: "숲", interests: ["러닝", "기록", "산책", "독서", "사진"]),
            ChatProfile(id: "screenshot-yoon", name: "윤슬", interests: ["기록", "음악", "산책", "사진"]),
            ChatProfile(id: "screenshot-moon", name: "달빛", interests: ["독서", "음악", "산책"]),
            ChatProfile(id: "screenshot-walk", name: "느린걸음", interests: ["러닝", "산책"])
        ]
        rooms = [
            ChatRoom(id: "screenshot-forest__screenshot-owner", person: profiles[0], status: .active, isIncoming: false, updatedAt: .now.addingTimeInterval(-180), lastMessage: "산책길에서 만난 작은 풍경이 좋았어요.", hasUnread: true),
            ChatRoom(id: "screenshot-owner__screenshot-yoon", person: profiles[1], status: .active, isIncoming: true, updatedAt: .now.addingTimeInterval(-3600), lastMessage: "저도 오늘은 천천히 걸어보려고요."),
            ChatRoom(id: "screenshot-moon__screenshot-owner", person: profiles[2], status: .pending, isIncoming: true, updatedAt: .now.addingTimeInterval(-7200))
        ]
        profileLoaded = true
    }

    private static var screenshotMessages: [ChatMessage] {
        let lines: [(String, Bool)] = [
            ("안녕하세요! 산책과 기록을 좋아하시는군요.", false),
            ("네, 걷다가 떠오른 생각을 적곤 해요.", true),
            ("오늘은 어떤 순간을 담으셨나요?", false),
            ("나뭇잎 사이로 들어오는 햇빛이 예뻤어요. 잠깐 멈춰서 바라봤어요.", true),
            ("산책길에서 만난 작은 풍경이 좋았어요.", false)
        ]
        return lines.enumerated().map { index, value in
            ChatMessage(id: "screenshot-message-\(index)", body: value.0,
                        createdAt: .now.addingTimeInterval(Double(index - 5) * 180), isMine: value.1, delivery: .sent)
        }
    }
    #endif

    init(session: AppleSession? = nil) {
        let session = session ?? AppleSession.shared
        sessionSubscription = session.$userID.removeDuplicates().sink { [weak self] userID in
            Task { @MainActor in
                guard session.userID == userID else { return }
                self?.connect(userID: userID)
            }
        }
    }

    var activeRooms: [ChatRoom] { rooms.filter { $0.status == .active && !$0.isArchived && !$0.isBlocked } }
    var incomingRequests: [ChatRoom] { rooms.filter { $0.status == .pending && $0.isIncoming && !$0.isBlocked } }
    var outgoingRequests: [ChatRoom] { rooms.filter { $0.status == .pending && !$0.isIncoming && !$0.isBlocked } }
    var blockedRooms: [ChatRoom] { rooms.filter(\.isBlocked) }
    var unreadCount: Int { activeRooms.filter(\.hasUnread).count + incomingRequests.count }
    func room(id: String) -> ChatRoom? { rooms.first { $0.id == id } }
    func room(for personID: String) -> ChatRoom? { rooms.first { $0.person.id == personID } }

    func reconnect() { connect(userID: AppleSession.shared.userID) }

    private func connect(userID: String?) {
        generation = UUID()
        closeChat()
        listeners.forEach { $0.remove() }; listeners = []
        roomListeners.values.flatMap { $0 }.forEach { $0.remove() }; roomListeners = [:]
        latestListeners.values.forEach { $0.remove() }; latestListeners = [:]
        database = nil; cache = nil; currentUserID = userID
        profiles = []; rooms = []; publishedProfile = nil; profileLoaded = false
        roomData = [:]; knownProfiles = [:]; discoveryIDs = []; blockedIDs = []
        states = [:]; latestMessages = [:]; writingRead = []; sendingIDs = []
        profileCursor = nil; hasMoreProfiles = false; hasLoadedMoreProfiles = false; errorMessage = nil; isLoading = false
        #if DEBUG
        if NaldamRuntime.isStoreScreenshot, userID != nil {
            loadScreenshotFixtures()
            return
        }
        #endif
        guard let userID, FirebaseBootstrap.configureIfAvailable() else { return }
        let db = Firestore.firestore()
        database = db
        cache = ChatLocalCache(userID: userID)
        errorMessage = cache?.errorMessage
        isLoading = true
        let token = generation

        listeners.append(db.collection("profiles").document(userID).addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                if let error { self.report(error); return }
                guard let snapshot, !snapshot.metadata.hasPendingWrites else { return }
                // An empty cache is not proof that this account has no public profile.
                if !snapshot.exists && snapshot.metadata.isFromCache { return }
                self.publishedProfile = Self.profile(snapshot)
                self.profileLoaded = true
            }
        })
        listeners.append(db.collection("profiles").order(by: FieldPath.documentID()).limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if let error { self.report(error); self.isLoading = false; return }
                    guard let snapshot else { return }
                    for document in snapshot.documents {
                        if let profile = Self.profile(document) {
                            self.knownProfiles[profile.id] = profile
                            self.discoveryIDs.insert(profile.id)
                        }
                    }
                    for change in snapshot.documentChanges where change.type == .removed {
                        self.discoveryIDs.remove(change.document.documentID)
                    }
                    if !snapshot.metadata.isFromCache, !self.hasLoadedMoreProfiles {
                        self.profileCursor = snapshot.documents.last
                        self.hasMoreProfiles = snapshot.documents.count == 100
                    }
                    self.isLoading = false
                    self.rebuildRooms()
                }
            })
        listeners.append(db.collection("users").document(userID).collection("blocks")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if let error { self.report(error); return }
                    guard let snapshot else { return }
                    self.blockedIDs = Set(snapshot.documents.map(\.documentID))
                    self.rebuildRooms()
                }
            })
        listeners.append(db.collection("rooms").whereField("members", arrayContains: userID)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if let error { self.report(error); return }
                    guard let snapshot else { return }
                    let previous = self.roomData
                    self.roomData = Dictionary(uniqueKeysWithValues: snapshot.documents.compactMap { document in
                        if document.metadata.hasPendingWrites {
                            return previous[document.documentID].map { (document.documentID, $0) }
                        }
                        return (document.documentID, document.data())
                    })
                    for id in Array(self.roomListeners.keys) where self.roomData[id] == nil {
                        self.roomListeners.removeValue(forKey: id)?.forEach { $0.remove() }
                        self.latestListeners.removeValue(forKey: id)?.remove()
                        self.states[id] = nil; self.latestMessages[id] = nil
                    }
                    for (id, data) in self.roomData { self.observeRoom(id: id, data: data, userID: userID, token: token) }
                    self.rebuildRooms()
                }
            })
    }

    func loadMoreProfiles() async {
        guard let db = database, let cursor = profileCursor, hasMoreProfiles, !isLoading else { return }
        let token = generation
        isLoading = true
        do {
            let snapshot = try await db.collection("profiles").order(by: FieldPath.documentID())
                .start(afterDocument: cursor).limit(to: 100).getDocuments(source: .server)
            guard generation == token else { return }
            for document in snapshot.documents {
                if let profile = Self.profile(document) { knownProfiles[profile.id] = profile; discoveryIDs.insert(profile.id) }
            }
            profileCursor = snapshot.documents.last ?? cursor
            hasLoadedMoreProfiles = true
            hasMoreProfiles = snapshot.documents.count == 100
            rebuildRooms()
        } catch { if generation == token { report(error) } }
        if generation == token { isLoading = false }
    }

    private func observeRoom(id: String, data: [String: Any], userID: String, token: UUID) {
        guard let db = database, let members = data["members"] as? [String],
              let other = members.first(where: { $0 != userID }) else { return }
        if roomListeners[id] == nil {
            let stateListener = db.collection("rooms").document(id).collection("states").document(userID)
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        if let error { self.report(error); return }
                        self.states[id] = snapshot?.data() ?? [:]
                        self.rebuildRooms()
                        if self.activeRoomID == id { self.markRead(id: id) }
                    }
                }
            let profileListener = db.collection("profiles").document(other).addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self, self.generation == token, let snapshot else { return }
                    self.knownProfiles[other] = Self.profile(snapshot)
                    self.rebuildRooms()
                }
            }
            roomListeners[id] = [stateListener, profileListener]
        }
        if data["status"] as? String == "active", latestListeners[id] == nil {
            latestListeners[id] = db.collection("rooms").document(id).collection("messages")
                .order(by: "createdAt", descending: true).limit(to: 1)
                .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        if let error { self.report(error); return }
                        self.latestMessages[id] = snapshot?.documents.first.flatMap { Self.message($0, userID: userID) }
                        self.rebuildRooms()
                        if self.activeRoomID == id { self.markRead(id: id) }
                    }
                }
        }
    }

    private func rebuildRooms() {
        guard let userID = currentUserID else { return }
        profiles = discoveryIDs.compactMap { knownProfiles[$0] }
            .filter { $0.id != userID && !blockedIDs.contains($0.id) }.sorted { $0.name < $1.name }
        rooms = roomData.compactMap { id, data in
            guard let members = data["members"] as? [String], members.contains(userID),
                  let other = members.first(where: { $0 != userID }),
                  let raw = data["status"] as? String, let status = ChatRoomStatus(rawValue: raw) else { return nil }
            let latest = latestMessages[id]
            let readAt = (states[id]?["lastReadAt"] as? Timestamp)?.dateValue() ?? .distantPast
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
            return ChatRoom(id: id, person: knownProfiles[other] ?? ChatProfile(id: other, name: "친구", interests: []),
                            status: status, isIncoming: data["recipientID"] as? String == userID,
                            isArchived: states[id]?["archived"] as? Bool ?? false,
                            isBlocked: blockedIDs.contains(other), updatedAt: max(updatedAt, latest?.createdAt ?? .distantPast),
                            lastMessage: latest?.body, hasUnread: latest.map { !$0.isMine && $0.createdAt > readAt } ?? false)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func publishProfile(name: String, interests: [String]) async -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = ChatValidation.interests(interests)
        guard !name.isEmpty, name.count <= 12, name.utf16.count <= 1_024,
              tags.allSatisfy({ InterestTagCatalog.customTag(from: $0) != nil && $0.utf16.count <= 256 }),
              let userID = currentUserID, let db = database else {
            errorMessage = "이름은 1~12글자, 관심사는 각각 5글자 이내로 확인해 주세요."
            return false
        }
        let token = generation
        let reference = db.collection("profiles").document(userID)
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    let existing = try transaction.getDocument(reference)
                    var data: [String: Any] = ["name": name, "interests": tags, "updatedAt": FieldValue.serverTimestamp()]
                    data["createdAt"] = existing.data()?["createdAt"] ?? FieldValue.serverTimestamp()
                    transaction.setData(data, forDocument: reference)
                    return nil
                } catch { errorPointer?.pointee = error as NSError; return nil }
            }
            guard generation == token else { return false }
            errorMessage = nil
            return true
        } catch { if generation == token { report(error) }; return false }
    }

    func requestConversation(with person: ChatProfile) async -> String? {
        guard let userID = currentUserID, let db = database, publishedProfile != nil,
              !blockedIDs.contains(person.id), let id = ChatValidation.roomID(userID, person.id) else { return nil }
        if let existing = room(for: person.id) {
            if existing.status == .declined { errorMessage = "종료된 인사예요. 새로운 요청은 보낼 수 없어요."; return nil }
            if existing.isArchived, !(await setState(id: existing.id, fields: ["archived": false])) { return nil }
            return existing.id
        }
        let token = generation
        let reference = db.collection("rooms").document(id)
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    let existing = try transaction.getDocument(reference)
                    if existing.exists { return nil }
                    transaction.setData(["members": [userID, person.id].sorted(), "senderID": userID, "recipientID": person.id,
                                         "status": "pending", "createdAt": FieldValue.serverTimestamp(),
                                         "updatedAt": FieldValue.serverTimestamp()], forDocument: reference)
                    return nil
                } catch { errorPointer?.pointee = error as NSError; return nil }
            }
            guard generation == token else { return nil }
            errorMessage = nil
            return id
        } catch { if generation == token { report(error) }; return nil }
    }

    func acceptRequest(id: String) async -> Bool {
        guard let room = room(id: id), room.status == .pending, room.isIncoming, !room.isBlocked else { return false }
        return await changeStatus(id: id, status: "active")
    }

    func declineRequest(id: String) async -> Bool {
        guard room(id: id)?.status == .pending else { return false }
        return await changeStatus(id: id, status: "declined")
    }

    private func changeStatus(id: String, status: String) async -> Bool {
        guard let db = database else { return false }
        let token = generation
        do {
            try await db.collection("rooms").document(id).updateData(["status": status, "updatedAt": FieldValue.serverTimestamp()])
            guard generation == token else { return false }
            errorMessage = nil
            return true
        } catch { if generation == token { report(error) }; return false }
    }

    func setBlocked(_ blocked: Bool, id: String) async -> Bool {
        guard let userID = currentUserID, let db = database, let room = room(id: id) else { return false }
        let token = generation
        let reference = db.collection("users").document(userID).collection("blocks").document(room.person.id)
        do {
            if blocked { try await reference.setData(["createdAt": FieldValue.serverTimestamp()]) }
            else { try await reference.delete() }
            guard generation == token else { return false }
            errorMessage = nil
            return true
        } catch { if generation == token { report(error) }; return false }
    }

    func archive(id: String) async -> Bool { await setState(id: id, fields: ["archived": true]) }

    private func setState(id: String, fields: [String: Any]) async -> Bool {
        guard let userID = currentUserID, let db = database else { return false }
        let token = generation
        do {
            try await db.collection("rooms").document(id).collection("states").document(userID).setData(fields, merge: true)
            guard generation == token else { return false }
            errorMessage = nil
            return true
        } catch { if generation == token { report(error) }; return false }
    }

    func markRead(id: String) {
        guard activeRoomID == id, UIApplication.shared.applicationState == .active,
              let latest = latestMessages[id], !latest.isMine, latest.delivery == .sent,
              states[id] != nil, room(id: id)?.hasUnread == true, !writingRead.contains(id) else { return }
        writingRead.insert(id)
        let token = generation
        let observedAt = latest.createdAt
        Task {
            let saved = await saveReadBoundary(id: id, observedAt: observedAt)
            guard generation == token else { return }
            writingRead.remove(id)
            if saved {
                let previous = (states[id]?["lastReadAt"] as? Timestamp)?.dateValue() ?? .distantPast
                states[id, default: [:]]["lastReadAt"] = Timestamp(date: max(previous, observedAt))
                rebuildRooms()
                if activeRoomID == id { markRead(id: id) }
            }
        }
    }

    private func saveReadBoundary(id: String, observedAt: Date) async -> Bool {
        guard let db = database, let userID = currentUserID else { return false }
        let token = generation
        let reference = db.collection("rooms").document(id).collection("states").document(userID)
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(reference)
                    let previous = (snapshot.data()?["lastReadAt"] as? Timestamp)?.dateValue() ?? .distantPast
                    if observedAt > previous {
                        transaction.setData(["lastReadAt": Timestamp(date: observedAt)], forDocument: reference, merge: true)
                    }
                    return nil
                } catch { errorPointer?.pointee = error as NSError; return nil }
            }
            return generation == token
        } catch { if generation == token { report(error) }; return false }
    }

    func draft(for id: String) -> String { cache?.contents.drafts[id] ?? "" }

    @discardableResult
    func saveDraft(_ text: String, in id: String) -> Bool {
        guard let cache else { return false }
        guard draft(for: id) != text else { return true }
        let success = cache.change { $0.drafts[id] = text }
        if !success { errorMessage = cache.errorMessage }
        return success
    }

    @discardableResult
    func openChat(id: String) -> UUID? {
        closeChat()
        #if DEBUG
        if NaldamRuntime.isStoreScreenshot {
            guard room(id: id)?.status == .active else { return nil }
            activeRoomID = id
            messages = Self.screenshotMessages
            return chatGeneration
        }
        #endif
        guard let db = database, let userID = currentUserID, room(id: id)?.status == .active else { return nil }
        activeRoomID = id
        let token = generation, chatToken = chatGeneration
        messageListener = db.collection("rooms").document(id).collection("messages")
            .order(by: "createdAt", descending: true).limit(to: 50)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.generation == token, self.chatGeneration == chatToken else { return }
                    if let error { self.report(error); return }
                    guard let snapshot else { return }
                    for document in snapshot.documents {
                        guard let message = Self.message(document, userID: userID) else { continue }
                        self.remoteMessages[message.id] = message
                        if message.delivery == .sent { self.removeOutbox(id: message.id) }
                    }
                    if !snapshot.metadata.isFromCache, !self.hasLoadedOlderPage {
                        self.oldestMessage = snapshot.documents.last
                        self.hasOlderMessages = snapshot.documents.count == 50
                    }
                    self.rebuildMessages()
                    self.markRead(id: id)
                }
            }
        rebuildMessages()
        markRead(id: id)
        return chatToken
    }

    func closeChat(token: UUID?) {
        guard token == chatGeneration else { return }
        closeChat()
    }

    func closeChat() {
        chatGeneration = UUID()
        messageListener?.remove(); messageListener = nil
        activeRoomID = nil; remoteMessages = [:]; messages = []
        oldestMessage = nil; hasOlderMessages = false; loadingOlder = false; hasLoadedOlderPage = false
    }

    func loadOlderMessages() async {
        guard let id = activeRoomID, let userID = currentUserID, let db = database,
              let cursor = oldestMessage, hasOlderMessages, !loadingOlder else { return }
        loadingOlder = true
        let token = generation, chatToken = chatGeneration
        do {
            let snapshot = try await db.collection("rooms").document(id).collection("messages")
                .order(by: "createdAt", descending: true).start(afterDocument: cursor).limit(to: 50).getDocuments(source: .server)
            guard generation == token, chatGeneration == chatToken else { return }
            for document in snapshot.documents {
                if let message = Self.message(document, userID: userID) { remoteMessages[message.id] = message }
            }
            oldestMessage = snapshot.documents.last ?? cursor
            hasLoadedOlderPage = true
            hasOlderMessages = snapshot.documents.count == 50
            rebuildMessages()
        } catch { if generation == token, chatGeneration == chatToken { report(error) } }
        if generation == token, chatGeneration == chatToken { loadingOlder = false }
    }

    /// True means safely queued locally; the bubble remains sending until the server confirms it.
    @discardableResult
    func send(_ text: String, in roomID: String) -> Bool {
        guard let body = ChatValidation.message(text), let cache, currentUserID != nil,
              let room = room(id: roomID), room.status == .active, !room.isBlocked, !room.isArchived else { return false }
        let item = ChatOutboxItem(id: UUID().uuidString, roomID: roomID, body: body, createdAt: Date(), delivery: .sending)
        guard cache.change({ $0.outbox.append(item); $0.drafts[roomID] = nil }) else {
            errorMessage = cache.errorMessage; return false
        }
        rebuildMessages()
        transmit(item)
        return true
    }

    func retry(messageID: String) {
        guard let item = cache?.contents.outbox.first(where: { $0.id == messageID }),
              room(id: item.roomID)?.status == .active, room(id: item.roomID)?.isBlocked == false else { return }
        transmit(item)
    }

    private func transmit(_ item: ChatOutboxItem) {
        guard let db = database, let userID = currentUserID, let cache, !sendingIDs.contains(item.id) else { return }
        guard cache.change({ contents in
            if let index = contents.outbox.firstIndex(where: { $0.id == item.id }) { contents.outbox[index].delivery = .sending }
        }) else { errorMessage = cache.errorMessage; return }
        sendingIDs.insert(item.id)
        rebuildMessages()
        let token = generation
        let reference = db.collection("rooms").document(item.roomID).collection("messages").document(item.id)
        Task {
            do {
                // A retry after an app restart never creates a duplicate or changes a delivered message.
                let confirmedTimestamp = try await db.runTransaction { transaction, errorPointer -> Any? in
                    do {
                        let existing = try transaction.getDocument(reference)
                        if existing.exists {
                            guard existing.data()?["senderID"] as? String == userID,
                                  existing.data()?["body"] as? String == item.body else {
                                throw NSError(domain: "NaldamChat", code: 1)
                            }
                            return existing.data()?["createdAt"]
                        }
                        transaction.setData(["senderID": userID, "body": item.body,
                                             "createdAt": FieldValue.serverTimestamp()], forDocument: reference)
                        return nil
                    } catch { errorPointer?.pointee = error as NSError; return nil }
                }
                guard generation == token else { return }
                // The query listener supplies the authoritative timestamp. Keep a confirmed copy until it arrives.
                if activeRoomID == item.roomID, remoteMessages[item.id] == nil {
                    remoteMessages[item.id] = ChatMessage(id: item.id, body: item.body,
                                                         createdAt: (confirmedTimestamp as? Timestamp)?.dateValue() ?? item.createdAt,
                                                         isMine: true, delivery: .sent)
                }
                removeOutbox(id: item.id)
                errorMessage = nil
            } catch {
                guard generation == token else { return }
                _ = cache.change { contents in
                    if let index = contents.outbox.firstIndex(where: { $0.id == item.id }) { contents.outbox[index].delivery = .failed }
                }
                report(error)
            }
            guard generation == token else { return }
            sendingIDs.remove(item.id)
            rebuildMessages()
        }
    }

    private func removeOutbox(id: String) {
        guard let cache, cache.contents.outbox.contains(where: { $0.id == id }) else { return }
        if !cache.change({ $0.outbox.removeAll { $0.id == id } }) { errorMessage = cache.errorMessage }
    }

    private func rebuildMessages() {
        guard let id = activeRoomID else { messages = []; return }
        var merged = remoteMessages
        for item in cache?.contents.outbox ?? [] where item.roomID == id && merged[item.id]?.delivery != .sent {
            merged[item.id] = ChatMessage(id: item.id, body: item.body, createdAt: item.createdAt, isMine: true,
                                         delivery: item.delivery, error: item.delivery == .failed ? "전송하지 못했어요. 다시 시도해 주세요." : nil)
        }
        messages = merged.values.sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
        }
    }

    private static func profile(_ snapshot: DocumentSnapshot) -> ChatProfile? {
        guard let data = snapshot.data(), let name = data["name"] as? String,
              let interests = data["interests"] as? [String] else { return nil }
        let tags = ChatValidation.interests(interests).filter { InterestTagCatalog.customTag(from: $0) != nil }
        return ChatProfile(id: snapshot.documentID, name: String(name.prefix(12)), interests: tags)
    }

    private static func message(_ snapshot: DocumentSnapshot, userID: String) -> ChatMessage? {
        guard let data = snapshot.data(), let body = data["body"] as? String,
              let sender = data["senderID"] as? String else { return nil }
        return ChatMessage(id: snapshot.documentID, body: body,
                           createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                           isMine: sender == userID, delivery: snapshot.metadata.hasPendingWrites ? .sending : .sent)
    }

    private func report(_ error: Error) {
        let code = (error as NSError).code
        switch code {
        case FirestoreErrorCode.permissionDenied.rawValue:
            errorMessage = "요청을 처리할 수 없어요. 대화 수락·차단 상태 또는 연결 설정을 확인해 주세요."
        case FirestoreErrorCode.unauthenticated.rawValue:
            errorMessage = "로그인이 만료됐어요. 다시 로그인해 주세요."
        case FirestoreErrorCode.unavailable.rawValue, FirestoreErrorCode.deadlineExceeded.rawValue:
            errorMessage = "연결이 원활하지 않아요. 인터넷 연결을 확인하고 다시 시도해 주세요."
        default:
            errorMessage = "연결을 완료하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}
