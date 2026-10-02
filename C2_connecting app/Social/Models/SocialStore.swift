import Foundation
import Combine

/// This store has no network connection. A successful send means an atomic local save only.
@MainActor
final class SocialStore: ObservableObject {
    static let shared: SocialStore = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-naldam-ui-testing") {
            return SocialStore(fileURL: URL.temporaryDirectory.appending(path: "naldam-ui-\(UUID().uuidString).json"))
        }
        #endif
        return SocialStore()
    }()

    @Published private(set) var conversations: [LocalConversation] = []
    @Published private(set) var storageError: String?
    private let fileURL: URL
    private var canWrite = true

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory
            .appending(path: "Naldam", directoryHint: .isDirectory)
            .appending(path: "social-v1.json")
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                let data = try JSONDecoder().decode(LocalSocialData.self, from: Data(contentsOf: self.fileURL))
                guard data.version == 1 else { throw SocialStorageError.unsupportedVersion }
                conversations = data.conversations
            }
        } catch {
            // Never overwrite a file that we could not read. The original remains recoverable.
            canWrite = false
            storageError = "저장된 대화를 읽지 못했어요. 기존 파일은 그대로 보관했으며, 앱을 다시 열어 확인해 주세요."
        }
    }

    var activeConversations: [LocalConversation] {
        conversations.filter { $0.status == .active && !$0.isArchived && !$0.isBlocked }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    var incomingRequests: [LocalConversation] {
        conversations.filter { $0.status == .incomingRequest && !$0.isArchived && !$0.isBlocked }
    }
    var outgoingRequests: [LocalConversation] {
        conversations.filter { $0.status == .outgoingRequest && !$0.isArchived && !$0.isBlocked }
    }
    var blockedConversations: [LocalConversation] { conversations.filter(\.isBlocked) }
    var unreadCount: Int { activeConversations.reduce(0) { $0 + $1.unreadCount } + incomingRequests.count }

    func conversation(id: UUID) -> LocalConversation? { conversations.first { $0.id == id } }
    func conversation(for personID: String) -> LocalConversation? {
        conversations.first { $0.personID == personID }
    }

    @discardableResult
    func requestConversation(with person: SamplePerson) -> Bool {
        commit { items in
            if let index = items.firstIndex(where: { $0.personID == person.id }) {
                guard !items[index].isBlocked else { return }
                // Existing messages are preserved when an archived conversation is reopened.
                items[index].isArchived = false
                if items[index].status == .declined { items[index].status = .outgoingRequest }
                items[index].updatedAt = Date()
            } else {
                items.append(.init(id: UUID(), personID: person.id, status: .outgoingRequest))
            }
        }
    }

    @discardableResult
    func addSampleRequests() -> Bool {
        commit { items in
            for personID in ["minseo", "jiwoo"] where !items.contains(where: { $0.personID == personID }) {
                items.append(.init(id: UUID(), personID: personID, status: .incomingRequest))
            }
        }
    }

    @discardableResult
    func acceptRequest(id: UUID) -> Bool {
        update(id: id) { item in
            guard !item.isBlocked, item.status == .incomingRequest || item.status == .outgoingRequest else { return }
            item.status = .active
            item.isArchived = false
            item.updatedAt = Date()
            if item.messages.isEmpty, let person = item.person {
                item.messages.append(.init(id: UUID(), body: person.greeting, createdAt: Date(), origin: .sample))
            }
        }
    }

    @discardableResult
    func declineRequest(id: UUID) -> Bool {
        update(id: id) { item in item.status = .declined; item.isArchived = true }
    }

    @discardableResult
    func saveDraft(_ text: String, id: UUID) -> Bool {
        guard let current = conversation(id: id), current.draft != text else { return true }
        return update(id: id) { $0.draft = text }
    }

    @discardableResult
    func send(_ text: String, id: UUID) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 2_000,
              let current = conversation(id: id), current.status == .active,
              !current.isArchived, !current.isBlocked else { return false }
        return update(id: id) { item in
            item.messages.append(.init(id: UUID(), body: trimmed, createdAt: Date(), origin: .me))
            item.draft = ""
            item.updatedAt = Date()
        }
    }

    func markRead(id: UUID) {
        guard let current = conversation(id: id), current.unreadCount > 0 else { return }
        update(id: id) { $0.lastReadAt = Date() }
    }

    @discardableResult
    func archive(id: UUID) -> Bool { update(id: id) { $0.isArchived = true } }

    @discardableResult
    func setBlocked(_ blocked: Bool, id: UUID) -> Bool {
        update(id: id) { $0.isBlocked = blocked }
    }

    @discardableResult
    private func update(id: UUID, change: (inout LocalConversation) -> Void) -> Bool {
        guard conversations.contains(where: { $0.id == id }) else { return false }
        return commit { items in
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            change(&items[index])
        }
    }

    private func commit(_ change: (inout [LocalConversation]) -> Void) -> Bool {
        guard canWrite else { return false }
        var next = conversations
        change(&next)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(LocalSocialData(conversations: next))
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            conversations = next
            storageError = nil
            return true
        } catch {
            storageError = "기기에 저장하지 못했어요. 저장 공간을 확인하고 다시 시도해 주세요. 입력한 내용은 화면에 남아 있어요."
            return false
        }
    }

    private enum SocialStorageError: Error { case unsupportedVersion }
}
