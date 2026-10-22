import SwiftUI

struct ConversationsView: View {
    @ObservedObject private var store = SocialStore.shared
    @State private var searchText = ""
    @State private var showingSampleConfirmation = false
    @State private var onlyUnread = false
    @State private var searchPresented = false
    private var unreadThreadCount: Int { store.activeConversations.filter { $0.unreadCount > 0 }.count }

    private var filteredConversations: [LocalConversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.activeConversations.filter {
            (!onlyUnread || $0.unreadCount > 0) && (query.isEmpty || $0.person?.name.localizedCaseInsensitiveContains(query) == true
                || $0.messages.contains { $0.body.localizedCaseInsensitiveContains(query) })
        }
    }
    private var canAddSampleRequests: Bool {
        ["minseo", "jiwoo"].contains { store.conversation(for: $0) == nil }
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
                            .frame(width: 44, height: 44)
                            .background(Color.naldamPaper, in: Circle())
                    }.accessibilityLabel(searchPresented ? "검색 닫기" : "대화 검색")
                    NavigationLink { BlockedPeopleView() } label: {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .frame(width: 44, height: 44)
                            .background(Color.naldamPaper, in: Circle())
                    }.accessibilityLabel("차단한 샘플 프로필 관리")
                }.foregroundStyle(Color.naldamInk)
                Text("작은 안부가 쌓여, 조금 더 가까이.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                if searchPresented { NaldamSearchField(text: $searchText, prompt: "이름이나 메시지 검색") }
                SocialStorageWarning(message: store.storageError)
                Picker("대화 보기", selection: $onlyUnread) {
                    Text("전체").tag(false)
                    Text("안 읽음 \(unreadThreadCount)").tag(true)
                }
                .pickerStyle(.segmented).accessibilityIdentifier("conversations.filter")
                if !store.incomingRequests.isEmpty { incomingRequestsCard }
                if !store.outgoingRequests.isEmpty { outgoingRequestsCard }
                HStack {
                    Text("이어가는 이야기").font(.subheadline.weight(.semibold))
                    Spacer()
                    if !store.activeConversations.isEmpty {
                        Text("\(store.activeConversations.count)")
                            .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                    }
                }.foregroundStyle(Color.naldamInk)
                if store.activeConversations.isEmpty {
                    NaldamEmptyState(symbol: "bubble.left.and.bubble.right", title: "첫 이야기를 기다리고 있어요", message: "발견에서 마음에 닿는 샘플 이야기를 읽고 대화 요청을 남겨 보세요.")
                } else if filteredConversations.isEmpty {
                    NaldamEmptyState(symbol: onlyUnread ? "envelope.open" : "magnifyingglass", title: onlyUnread ? "모든 이야기를 읽었어요" : "찾는 대화가 없어요", message: onlyUnread ? "새로운 이야기가 도착하면 이곳에서 볼 수 있어요." : "다른 이름이나 메시지로 검색해 보세요.")
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
                Label("서두르지 않아도 괜찮아요.", systemImage: "leaf")
                    .font(.footnote).foregroundStyle(Color.naldamSecondary)
                    .frame(maxWidth: .infinity)
                Label("샘플 대화 · 메시지는 이 기기에만 저장돼요", systemImage: "flask")
                    .font(.caption).foregroundStyle(Color.naldamSecondary)
                if canAddSampleRequests {
                    Button { showingSampleConfirmation = true } label: {
                        Label("받은 요청 체험하기", systemImage: "flask")
                            .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
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
        .confirmationDialog("가상의 요청을 추가할까요?", isPresented: $showingSampleConfirmation, titleVisibility: .visible) {
            Button("샘플 요청 추가") { store.addSampleRequests() }
        } message: {
            Text("민서와 지우의 샘플 요청을 이 기기에 추가해요. 실제 사람이 보낸 요청이 아닙니다.")
        }
    }

    private var incomingRequestsCard: some View {
        NavigationLink { SampleRequestsView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope").font(.title3.weight(.light))
                    .foregroundStyle(Color.naldamAccent).frame(width: 43, height: 47)
                    .background(Color.naldamSoft, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text("새로 도착한 인사").font(.subheadline.weight(.semibold)).foregroundStyle(Color.naldamInk)
                    Text(store.incomingRequests.count == 1 ? "\(store.incomingRequests.first?.person?.name ?? "친구")님이 인사를 건넸어요." : "\(store.incomingRequests.count)명의 친구가 인사를 건넸어요.")
                        .font(.caption).foregroundStyle(Color.naldamSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.naldamSecondary)
            }
            .padding(15).background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.naldamLine, lineWidth: 0.8))
        }
        .buttonStyle(.plain).accessibilityLabel("요청 모두 보기")
        .accessibilityHint("새로 도착한 인사를 모두 확인해요")
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
            if let person = conversation.person { NaldamPersonPortrait(person: person, size: 50) }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.person?.name ?? "샘플 대화").font(.headline)
                }
                if !conversation.draft.isEmpty {
                    Text("작성 중: \(conversation.draft)").foregroundStyle(Color.naldamAccent)
                        .font(.subheadline).lineLimit(1)
                } else {
                    Text(conversation.messages.last?.body ?? "이야기를 시작해 보세요")
                        .font(.subheadline).foregroundStyle(Color.naldamSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 8) {
                Text(conversation.updatedAt, style: .relative).font(.caption2).foregroundStyle(Color.naldamSecondary)
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
        .naldamTabBarHidden()
    }
}
