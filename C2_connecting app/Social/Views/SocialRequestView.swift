import SwiftUI

struct SocialRequestView: View {
    let person: ChatProfile
    @ObservedObject private var store = LiveChatStore.shared
    @State private var showingDeclineConfirmation = false
    @State private var busy = false
    private var room: ChatRoom? { store.room(for: person.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SocialStorageWarning(message: store.errorMessage)
                SocialPersonHeading(person: person)
                VStack(alignment: .leading, spacing: 12) {
                    Text("좋아하는 것에서 시작해요").font(.headline).foregroundStyle(Color.naldamAccent)
                    SocialInterestTags(tags: person.interests)
                    NavigationLink("공개 프로필 보기") { PublicPersonView(person: person) }
                        .font(.subheadline).frame(minHeight: 44)
                }.naldamCard()
                requestState
                if busy { ProgressView("인사를 연결하고 있어요").frame(maxWidth: .infinity) }
            }.padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("대화 요청").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).naldamTabBarHidden()
        .confirmationDialog("이 요청을 닫을까요?", isPresented: $showingDeclineConfirmation, titleVisibility: .visible) {
            Button("요청 닫기", role: .destructive) {
                if let room { perform { _ = await store.declineRequest(id: room.id) } }
            }
        } message: { Text("닫은 요청으로는 대화를 시작할 수 없어요.") }
    }

    @ViewBuilder private var requestState: some View {
        if let room, room.isBlocked {
            NaldamEmptyState(symbol: "hand.raised", title: "차단한 프로필이에요", message: "대화 탭의 차단 관리에서 해제할 수 있어요.")
        } else if let room, room.status == .active {
            if room.isArchived {
                Text("목록에서 숨긴 대화예요. 다시 열어도 기존 메시지는 유지돼요.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                Button("대화 다시 열기") { perform { _ = await store.requestConversation(with: person) } }
                    .buttonStyle(NaldamPrimaryButtonStyle()).disabled(busy)
            } else {
                Label("이제 이야기를 나눌 수 있어요", systemImage: "checkmark.circle")
                    .foregroundStyle(Color.naldamAccent)
                NavigationLink { ChatDetailView(conversationID: room.id) } label: {
                    Text("대화 열기")
                }.buttonStyle(NaldamPrimaryButtonStyle())
            }
        } else if let room, room.status == .pending && room.isIncoming {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(person.name)님이 인사를 건넸어요").font(.headline)
                Text("수락하면 두 사람만의 대화를 시작해요. 개인 기록은 함께 전달되지 않아요.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
            }
            Button("인사 수락하기") { perform { _ = await store.acceptRequest(id: room.id) } }
                .buttonStyle(NaldamPrimaryButtonStyle()).disabled(busy)
                .accessibilityIdentifier("request.accept")
            Button("거절") { showingDeclineConfirmation = true }
                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44).disabled(busy)
        } else if let room, room.status == .pending {
            VStack(alignment: .leading, spacing: 10) {
                Label("인사를 건넸어요", systemImage: "envelope.badge").font(.headline)
                Text("상대가 수락하면 대화를 시작할 수 있어요. 천천히 기다려 주세요.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
            }
            Button("요청 취소") { showingDeclineConfirmation = true }
                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44).disabled(busy)
        } else if let room, room.status == .declined {
            NaldamEmptyState(symbol: "envelope", title: "마무리된 인사예요", message: "닫힌 요청은 다시 보내지 않아요. 발견에서 다른 친구를 만나보세요.")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("이야기가 궁금한 마음을 남겨요").font(.title3.weight(.semibold))
                Text("이름과 관심사로 인사를 건네요. 상대가 수락해야 메시지를 주고받을 수 있어요.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
            }
            Button("인사 건네기") { perform { _ = await store.requestConversation(with: person) } }
                .buttonStyle(NaldamPrimaryButtonStyle()).disabled(busy)
                .accessibilityIdentifier("request.send")
        }
    }

    private func perform(_ operation: @escaping @MainActor () async -> Void) {
        guard !busy else { return }
        busy = true
        Task { await operation(); busy = false }
    }
}

struct IncomingRequestsView: View {
    @ObservedObject private var store = LiveChatStore.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SocialStorageWarning(message: store.errorMessage)
                if store.incomingRequests.isEmpty {
                    NaldamEmptyState(symbol: "envelope.open", title: "받은 인사가 없어요", message: "인사가 도착하면 관심사를 살펴보고 대화를 선택할 수 있어요.")
                }
                ForEach(store.incomingRequests) { room in
                    NavigationLink { SocialRequestView(person: room.person) } label: {
                        HStack {
                            SocialPersonHeading(person: room.person)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").foregroundStyle(Color.naldamSecondary)
                        }.naldamCard()
                    }.buttonStyle(.plain)
                }
            }.padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("도착한 인사").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).naldamTabBarHidden()
    }
}
