import SwiftUI

struct ConversationsView: View {
    @ObservedObject private var store = LiveChatStore.shared
    @State private var searchText = ""
    @State private var onlyUnread = false
    @State private var searchPresented = false
    private var unreadThreadCount: Int { store.activeRooms.filter(\.hasUnread).count }
    private var filteredRooms: [ChatRoom] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.activeRooms.filter {
            (!onlyUnread || $0.hasUnread) && (query.isEmpty || $0.person.name.localizedCaseInsensitiveContains(query)
                || $0.lastMessage?.localizedCaseInsensitiveContains(query) == true)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("대화").font(.title.weight(.bold))
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("conversations.title")
                    Spacer()
                    Button {
                        searchPresented.toggle()
                        if !searchPresented { searchText = "" }
                    } label: {
                        Image(systemName: searchPresented ? "xmark" : "magnifyingglass")
                            .frame(width: 44, height: 44).background(Color.naldamPaper, in: Circle())
                    }.accessibilityLabel(searchPresented ? "검색 닫기" : "대화 검색")
                    NavigationLink { BlockedPeopleView() } label: {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .frame(width: 44, height: 44).background(Color.naldamPaper, in: Circle())
                    }.accessibilityLabel("차단한 프로필 관리")
                }.foregroundStyle(Color.naldamInk)
                Text("작은 안부가 쌓여, 조금 더 가까이.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                if searchPresented { NaldamSearchField(text: $searchText, prompt: "이름이나 최근 메시지 검색") }
                SocialStorageWarning(message: store.errorMessage)
                if store.errorMessage != nil {
                    Button("다시 연결하기") { store.reconnect() }.frame(minHeight: 44)
                }
                Picker("대화 보기", selection: $onlyUnread) {
                    Text("전체").tag(false)
                    Text("안 읽음 \(unreadThreadCount)").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("conversations.filter")
                if !store.incomingRequests.isEmpty { incomingRequestsCard }
                if !store.outgoingRequests.isEmpty { outgoingRequestsCard }
                HStack {
                    Text("이어가는 이야기").font(.subheadline.weight(.semibold))
                    Spacer()
                    if !store.activeRooms.isEmpty {
                        Text("\(store.activeRooms.count)").font(.subheadline).foregroundStyle(Color.naldamSecondary)
                    }
                }.foregroundStyle(Color.naldamInk)
                if store.isLoading && store.rooms.isEmpty {
                    ProgressView("대화를 불러오고 있어요").frame(maxWidth: .infinity).padding(24)
                } else if store.activeRooms.isEmpty {
                    NaldamEmptyState(symbol: "bubble.left.and.bubble.right", title: "첫 이야기를 기다리고 있어요", message: "발견에서 닮은 관심사를 찾고 인사를 건네 보세요. 상대가 수락하면 대화를 시작할 수 있어요.")
                } else if filteredRooms.isEmpty {
                    NaldamEmptyState(symbol: onlyUnread ? "envelope.open" : "magnifyingglass", title: onlyUnread ? "모든 이야기를 읽었어요" : "찾는 대화가 없어요", message: onlyUnread ? "새로운 이야기가 도착하면 이곳에서 볼 수 있어요." : "다른 이름이나 최근 메시지로 검색해 보세요.")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredRooms) { room in
                            NavigationLink { ChatDetailView(conversationID: room.id) } label: {
                                ConversationRow(conversation: room, draft: store.draft(for: room.id))
                            }.buttonStyle(.plain)
                            if room.id != filteredRooms.last?.id {
                                Rectangle().fill(Color.naldamLine).frame(height: 1).padding(.leading, 68)
                            }
                        }
                    }
                }
                Label("서두르지 않아도 괜찮아요.", systemImage: "leaf")
                    .font(.footnote).foregroundStyle(Color.naldamSecondary).frame(maxWidth: .infinity)
            }.padding(.horizontal, 22).padding(.top, 5).padding(.bottom, 105)
                .frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InterestEnvelopePocket().frame(height: 38).background(Color.appBackground)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .background { NaldamEnvelopeBackground() }
        .navigationTitle("대화").navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var incomingRequestsCard: some View {
        NavigationLink { IncomingRequestsView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope").font(.title3.weight(.light))
                    .foregroundStyle(Color.naldamAccent).frame(width: 43, height: 47)
                    .background(Color.naldamSoft, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text("새로 도착한 인사").font(.subheadline.weight(.semibold)).foregroundStyle(Color.naldamInk)
                    Text("\(store.incomingRequests.count)명의 친구가 인사를 건넸어요.")
                        .font(.caption).foregroundStyle(Color.naldamSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.naldamSecondary)
            }
            .padding(15).background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.naldamLine, lineWidth: 0.8))
        }.buttonStyle(.plain).accessibilityLabel("요청 모두 보기")
    }

    private var outgoingRequestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("내가 건넨 인사").font(.headline)
            ForEach(store.outgoingRequests) { room in
                NavigationLink { SocialRequestView(person: room.person) } label: {
                    HStack {
                        Text(room.person.name)
                        Spacer()
                        Text("수락 기다리는 중").font(.caption)
                        Image(systemName: "chevron.right").font(.caption)
                    }.frame(minHeight: 44)
                }
            }
        }.naldamCard()
    }
}

private struct ConversationRow: View {
    let conversation: ChatRoom
    let draft: String
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ChatPersonPortrait(person: conversation.person, size: 50)
            VStack(alignment: .leading, spacing: 5) {
                Text(conversation.person.name).font(.headline)
                if !draft.isEmpty {
                    Text("작성 중: \(draft)").foregroundStyle(Color.naldamAccent).font(.subheadline).lineLimit(1)
                } else {
                    Text(conversation.lastMessage ?? "이야기를 시작해 보세요")
                        .font(.subheadline).foregroundStyle(Color.naldamSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 8) {
                Text(conversation.updatedAt, style: .relative).font(.caption2).foregroundStyle(Color.naldamSecondary)
                if conversation.hasUnread {
                    Circle().fill(Color.naldamAccent).frame(width: 9, height: 9)
                        .accessibilityLabel("읽지 않은 메시지 있음")
                }
            }
        }.foregroundStyle(Color.naldamInk).padding(.vertical, 18).accessibilityElement(children: .combine)
    }
}

private struct BlockedPeopleView: View {
    @ObservedObject private var store = LiveChatStore.shared
    @State private var busyID: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SocialStorageWarning(message: store.errorMessage)
                if store.blockedRooms.isEmpty {
                    NaldamEmptyState(symbol: "hand.raised", title: "차단한 프로필이 없어요", message: "차단하면 새 메시지를 주고받을 수 없어요. 기존 메시지는 지워지지 않아요.")
                }
                ForEach(store.blockedRooms) { room in
                    HStack {
                        SocialPersonHeading(person: room.person)
                        Spacer()
                        Button {
                            busyID = room.id
                            Task {
                                _ = await store.setBlocked(false, id: room.id)
                                busyID = nil
                            }
                        } label: {
                            if busyID == room.id { ProgressView() } else { Text("해제") }
                        }.font(.subheadline.weight(.semibold)).frame(minHeight: 44).disabled(busyID != nil)
                    }.naldamCard()
                }
            }.padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("차단 관리").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).naldamTabBarHidden()
    }
}
