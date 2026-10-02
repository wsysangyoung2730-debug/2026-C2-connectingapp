import SwiftUI

struct ConversationsView: View {
    @ObservedObject private var store = SocialStore.shared
    @State private var searchText = ""
    @State private var showingSampleConfirmation = false

    private var filteredConversations: [LocalConversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.activeConversations.filter {
            query.isEmpty || $0.person?.name.localizedCaseInsensitiveContains(query) == true
                || $0.messages.contains { $0.body.localizedCaseInsensitiveContains(query) }
        }
    }
    private var canAddSampleRequests: Bool {
        ["minseo", "jiwoo"].contains { store.conversation(for: $0) == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("나와 닮은 이야기들을 들어 보세요.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                SocialSampleBanner()
                SocialStorageWarning(message: store.storageError)
                if !store.incomingRequests.isEmpty { incomingRequestsCard }
                if !store.outgoingRequests.isEmpty { outgoingRequestsCard }
                HStack {
                    Text("나눈 이야기").font(.title2.weight(.bold))
                    Spacer()
                    if !store.activeConversations.isEmpty {
                        Text("\(store.activeConversations.count)")
                            .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                    }
                }.foregroundStyle(Color.naldamInk)
                if store.activeConversations.isEmpty {
                    NaldamEmptyState(symbol: "bubble.left.and.bubble.right", title: "첫 이야기를 기다리고 있어요", message: "발견에서 마음에 닿는 샘플 이야기를 읽고 대화 요청을 남겨 보세요.")
                } else if filteredConversations.isEmpty {
                    NaldamEmptyState(symbol: "magnifyingglass", title: "찾는 대화가 없어요", message: "다른 이름이나 메시지로 검색해 보세요.")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredConversations) { item in
                            NavigationLink { ChatDetailView(conversationID: item.id) } label: {
                                ConversationRow(conversation: item)
                            }.buttonStyle(.plain)
                            if item.id != filteredConversations.last?.id {
                                Rectangle().fill(Color.naldamLine).frame(height: 1).padding(.leading, 68)
                            }
                        }
                    }
                }
                Label("내 기록은 대화에 자동으로 공유되지 않아요.", systemImage: "lock")
                    .font(.footnote).foregroundStyle(Color.naldamSecondary)
                    .frame(maxWidth: .infinity)
                if canAddSampleRequests {
                    Button { showingSampleConfirmation = true } label: {
                        Label("받은 요청 체험하기", systemImage: "flask")
                            .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }.padding(20).padding(.bottom, 30)
        }
        .background(Color.appBackground)
        .navigationTitle("대화").navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $searchText, prompt: "이름이나 메시지 검색")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { BlockedPeopleView() } label: { Image(systemName: "person.crop.circle.badge.checkmark") }
                    .accessibilityLabel("차단한 샘플 프로필 관리")
            }
        }
        .confirmationDialog("가상의 요청을 추가할까요?", isPresented: $showingSampleConfirmation, titleVisibility: .visible) {
            Button("샘플 요청 추가") { store.addSampleRequests() }
        } message: {
            Text("민서와 지우의 샘플 요청을 이 기기에 추가해요. 실제 사람이 보낸 요청이 아닙니다.")
        }
    }

    private var incomingRequestsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("받은 샘플 요청").font(.headline)
                Text("\(store.incomingRequests.count)").font(.caption.weight(.bold))
                    .foregroundStyle(.white).padding(7).background(Color.naldamAccent, in: Circle())
                Spacer()
            }
            ForEach(store.incomingRequests.prefix(2)) { item in
                if let person = item.person {
                    NavigationLink { SocialRequestView(person: person) } label: {
                        HStack {
                            SocialPersonHeading(person: person, subtitle: person.greeting)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").foregroundStyle(Color.naldamSecondary)
                        }
                    }.buttonStyle(.plain)
                }
            }
            NavigationLink { SampleRequestsView() } label: {
                HStack { Text("요청 모두 보기"); Spacer(); Image(systemName: "chevron.right") }
                    .font(.subheadline).frame(minHeight: 44)
            }
        }.naldamCard()
    }

    private var outgoingRequestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("남긴 샘플 요청").font(.headline)
            ForEach(store.outgoingRequests) { item in
                if let person = item.person {
                    NavigationLink { SocialRequestView(person: person) } label: {
                        HStack {
                            Text(person.name)
                            Spacer()
                            Text("로컬 요청 · 체험 계속하기").font(.caption)
                            Image(systemName: "chevron.right")
                        }.frame(minHeight: 44)
                    }
                }
            }
        }.naldamCard()
    }
}

private struct ConversationRow: View {
    let conversation: LocalConversation
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NaldamAvatar(name: conversation.person?.name ?? "?", size: 54)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.person?.name ?? "샘플 대화").font(.headline)
                    Text("샘플").font(.caption2).foregroundStyle(Color.naldamSecondary)
                }
                if !conversation.draft.isEmpty {
                    Text("작성 중: \(conversation.draft)").foregroundStyle(Color.naldamAccent)
                        .font(.subheadline).lineLimit(1)
                } else {
                    Text(conversation.messages.last?.body ?? "이야기를 시작해 보세요")
                        .font(.subheadline).foregroundStyle(Color.naldamSecondary).lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 8) {
                Text(conversation.updatedAt, style: .date).font(.caption2).foregroundStyle(Color.naldamSecondary)
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)").font(.caption.weight(.bold))
                        .foregroundStyle(.white).padding(7).background(Color.naldamAccent, in: Circle())
                        .accessibilityLabel("읽지 않은 샘플 메시지 \(conversation.unreadCount)개")
                }
            }
        }.foregroundStyle(Color.naldamInk).padding(.vertical, 18)
        .accessibilityElement(children: .combine)
    }
}

private struct BlockedPeopleView: View {
    @ObservedObject private var store = SocialStore.shared
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SocialStorageWarning(message: store.storageError)
                if store.blockedConversations.isEmpty {
                    NaldamEmptyState(symbol: "hand.raised", title: "차단한 프로필이 없어요", message: "차단하면 발견과 대화 목록에서 숨겨집니다. 기존 메시지는 지워지지 않아요.")
                }
                ForEach(store.blockedConversations) { item in
                    if let person = item.person {
                        HStack {
                            SocialPersonHeading(person: person, subtitle: "샘플 프로필")
                            Spacer()
                            Button("해제") { store.setBlocked(false, id: item.id) }
                                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }.naldamCard()
                    }
                }
            }.padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("차단 관리").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
