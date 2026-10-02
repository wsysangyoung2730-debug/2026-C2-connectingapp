import SwiftUI

struct SocialRequestView: View {
    let person: SamplePerson
    @ObservedObject private var store = SocialStore.shared
    @State private var showingDeclineConfirmation = false
    @State private var showingDemoConfirmation = false
    private var conversation: LocalConversation? { store.conversation(for: person.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SocialSampleBanner()
                SocialStorageWarning(message: store.storageError)
                SocialPersonHeading(person: person)
                VStack(alignment: .leading, spacing: 12) {
                    Text("이 이야기에서 시작해요")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.naldamAccent)
                    Text(person.storyTitle).font(.title2.weight(.bold)).foregroundStyle(Color.naldamInk)
                    NavigationLink("이야기 읽기") { SampleStoryView(person: person) }
                        .font(.subheadline).frame(minHeight: 44)
                }.naldamCard()
                requestState
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("대화 요청").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("샘플 요청을 거절할까요?", isPresented: $showingDeclineConfirmation, titleVisibility: .visible) {
            Button("요청 거절", role: .destructive) {
                if let conversation { store.declineRequest(id: conversation.id) }
            }
        } message: {
            Text("이 기기에 저장된 샘플 요청만 닫아요. 실제 사용자에게 알림이 가지 않아요.")
        }
        .confirmationDialog("상대 수락을 체험할까요?", isPresented: $showingDemoConfirmation, titleVisibility: .visible) {
            Button("샘플 수락 체험") {
                if let conversation { store.acceptRequest(id: conversation.id) }
            }
        } message: {
            Text("실제 상대의 수락이 아닙니다. 가상의 첫 메시지가 들어 있는 로컬 대화를 열어요.")
        }
    }

    @ViewBuilder private var requestState: some View {
        if let conversation, conversation.isBlocked {
            NaldamEmptyState(symbol: "hand.raised", title: "차단한 샘플 프로필이에요", message: "대화 탭의 차단 관리에서 해제할 수 있어요.")
        } else if let conversation, conversation.status == .active {
            if conversation.isArchived {
                Text("이전에 나간 대화예요. 다시 열어도 기존 메시지는 유지돼요.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                Button("대화 다시 열기") { store.requestConversation(with: person) }
                    .buttonStyle(NaldamPrimaryButtonStyle())
            } else {
                Label("샘플 대화가 준비됐어요", systemImage: "checkmark.circle")
                    .foregroundStyle(Color.naldamAccent)
                NavigationLink { ChatDetailView(conversationID: conversation.id) } label: {
                    Text("대화 열기")
                }.buttonStyle(NaldamPrimaryButtonStyle())
            }
        } else if let conversation, conversation.status == .incomingRequest && !conversation.isArchived {
            VStack(alignment: .leading, spacing: 10) {
                Text("받은 샘플 요청").font(.headline)
                Text(person.greeting).font(.body).foregroundStyle(Color.naldamSecondary)
                Text("수락하면 가상의 첫 메시지와 대화 입력을 체험할 수 있어요.")
                    .font(.footnote).foregroundStyle(Color.naldamSecondary)
            }
            Button("샘플 요청 수락") { store.acceptRequest(id: conversation.id) }
                .buttonStyle(NaldamPrimaryButtonStyle())
            Button("거절") { showingDeclineConfirmation = true }
                .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        } else if let conversation, conversation.status == .outgoingRequest && !conversation.isArchived {
            VStack(alignment: .leading, spacing: 10) {
                Label("이 기기에 요청을 남겼어요", systemImage: "envelope.badge")
                    .font(.headline).foregroundStyle(Color.naldamInk)
                Text("서버가 연결되지 않아 실제로 전달되지는 않아요. 아래 버튼으로 수락 이후 화면을 체험해 보세요.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
            }
            Button("샘플 수락 체험") { showingDemoConfirmation = true }
                .buttonStyle(NaldamPrimaryButtonStyle())
            Button("요청 취소") { store.declineRequest(id: conversation.id) }
                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("이야기가 궁금한 마음을 남겨요")
                    .font(.title3.weight(.semibold)).foregroundStyle(Color.naldamInk)
                Text("대화 요청에는 내 개인 기록이 포함되지 않아요. 지금은 요청과 대화 흐름을 확인하는 로컬 체험입니다.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
            }
            Button("샘플 요청 남기기") { store.requestConversation(with: person) }
                .buttonStyle(NaldamPrimaryButtonStyle())
        }
    }
}

struct SampleRequestsView: View {
    @ObservedObject private var store = SocialStore.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SocialSampleBanner()
                SocialStorageWarning(message: store.storageError)
                if store.incomingRequests.isEmpty {
                    NaldamEmptyState(symbol: "envelope.open", title: "받은 요청이 없어요", message: "요청이 생기면 먼저 이야기를 읽고 대화를 선택할 수 있어요.")
                }
                ForEach(store.incomingRequests) { item in
                    if let person = item.person {
                        NavigationLink { SocialRequestView(person: person) } label: {
                            HStack {
                                SocialPersonHeading(person: person, subtitle: person.greeting)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").foregroundStyle(Color.naldamSecondary)
                            }.naldamCard()
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("받은 샘플 요청").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
