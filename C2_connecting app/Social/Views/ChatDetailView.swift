import SwiftUI
import SwiftData

struct ChatDetailView: View {
    let conversationID: UUID
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SocialStore.shared
    @State private var draft = ""
    @State private var lastPersistedDraft = ""
    @State private var hasLoadedDraft = false
    @State private var showingBlockConfirmation = false
    @State private var showingLeaveConfirmation = false
    @FocusState private var composerFocused: Bool
    @Query(sort: \InterestSelection.updatedAt, order: .reverse) private var selections: [InterestSelection]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var suggestedQuestion: String { DailyQuestionProvider.question(for: .now) }

    private var conversation: LocalConversation? { store.conversation(id: conversationID) }
    private var canCompose: Bool {
        guard let conversation else { return false }
        return conversation.status == .active && !conversation.isArchived && !conversation.isBlocked
    }
    private var canSend: Bool {
        canCompose && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.count <= 2_000
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    SocialStorageWarning(message: store.storageError)
                    if let conversation, let person = conversation.person {
                        storyContext(person)
                        if conversation.messages.isEmpty {
                            NaldamEmptyState(symbol: "bubble.left", title: "첫 이야기를 남겨 보세요", message: "궁금했던 문장이나 공통 관심사로 시작해도 좋아요.")
                        }
                        ForEach(conversation.messages) { message in
                            ChatMessageBubble(message: message, person: person)
                        }
                        if canCompose && conversation.messages.count < 4 && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            questionSuggestion
                        }
                    } else {
                        NaldamEmptyState(symbol: "bubble.left", title: "대화를 찾을 수 없어요", message: "뒤로 돌아가 대화 목록을 확인해 주세요.")
                    }
                    Color.clear.frame(height: 1).id("conversation-bottom")
                }.padding(18).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: conversation?.messages.count ?? 0) { _, _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo("conversation-bottom", anchor: .bottom)
                }
            }
            .onChange(of: composerFocused) { _, focused in
                if focused { proxy.scrollTo("conversation-bottom", anchor: .bottom) }
            }
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if canCompose { composer }
        }
        .navigationTitle(conversation?.person?.name ?? "대화")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .naldamTabBarHidden()
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation?.person?.name ?? "대화").font(.headline)
                    Text("샘플 대화 · 기기에만 저장").font(.caption2).foregroundStyle(Color.naldamSecondary)
                }.accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("샘플 프로필 차단", systemImage: "hand.raised", role: .destructive) { showingBlockConfirmation = true }
                    Button("대화 나가기", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { showingLeaveConfirmation = true }
                } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("대화 관리")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { composerFocused = false }
            }
        }
        .onAppear {
            // Another instance of this conversation may have changed its draft while
            // this screen was behind a story/request detail. Never restore stale text.
            // A locally edited draft that failed to save is the one exception.
            if !hasLoadedDraft || draft == lastPersistedDraft {
                let savedDraft = conversation?.draft ?? ""
                lastPersistedDraft = savedDraft
                draft = savedDraft
                hasLoadedDraft = true
            }
            store.markRead(id: conversationID)
        }
        .onChange(of: draft) { _, _ in persistDraftIfNeeded() }
        .onDisappear { composerFocused = false; persistDraftIfNeeded() }
        .confirmationDialog("이 샘플 프로필을 차단할까요?", isPresented: $showingBlockConfirmation, titleVisibility: .visible) {
            Button("차단", role: .destructive) {
                if store.setBlocked(true, id: conversationID) { dismiss() }
            }
        } message: {
            Text("발견과 대화 목록에서 숨겨져요. 기록과 메시지는 지우지 않으며, 대화 탭의 차단 관리에서 해제할 수 있어요.")
        }
        .confirmationDialog("이 대화에서 나갈까요?", isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
            Button("대화 나가기", role: .destructive) {
                if store.archive(id: conversationID) { dismiss() }
            }
        } message: {
            Text("목록에서만 숨겨지고 메시지와 초안은 기기에 남아요. 발견에서 같은 샘플 프로필의 대화를 다시 열 수 있어요.")
        }
    }

    private func persistDraftIfNeeded() {
        guard hasLoadedDraft, draft != lastPersistedDraft else { return }
        if store.saveDraft(draft, id: conversationID) { lastPersistedDraft = draft }
    }

    private func storyContext(_ person: SamplePerson) -> some View {
        let shared = person.sharedInterests(with: selections.first?.tags ?? [])
        return VStack(spacing: 8) {
            Image(systemName: "leaf").font(.system(size: 24, weight: .light)).foregroundStyle(Color.naldamAccent)
            Text(shared.isEmpty ? "공개한 이야기로 만난 사이." : "\(shared.joined(separator: " · "))으로 만난 사이.")
                .font(.subheadline).foregroundStyle(Color.naldamAccent)
                .multilineTextAlignment(.center)
            Text("가벼운 안부부터 나눠보세요.")
                .font(.caption).foregroundStyle(Color.naldamSecondary)
            NavigationLink { SampleStoryView(person: person) } label: {
                Text("이야기 다시 읽기").font(.caption).frame(minHeight: 36)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 6)
    }

    private var questionSuggestion: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("첫 이야기가 어렵다면", systemImage: "bubble.left")
                .font(.caption).foregroundStyle(Color.naldamSecondary)
            Text(suggestedQuestion).font(.subheadline).foregroundStyle(Color.naldamInk)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Button {
                draft = suggestedQuestion
                composerFocused = true
            } label: {
                HStack {
                    Text("이 질문으로 이야기하기")
                    Spacer(minLength: 5)
                    Image(systemName: "arrow.up.right")
                }.font(.caption).frame(minHeight: 36)
            }
            .accessibilityIdentifier("chat.prompt")
        }
        .padding(16).background(Color.naldamSoft, in: RoundedRectangle(cornerRadius: 18))
        .padding(.top, 6)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if draft.count > 2_000 {
                Text("메시지는 2,000자까지 남길 수 있어요. (현재 \(draft.count)자)")
                    .font(.caption).foregroundStyle(Color.naldamAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("따뜻한 한마디를 남겨보세요", text: $draft, axis: .vertical)
                    .font(.body).lineLimit(1...5)
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(Color.naldamPaper.opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
                    .focused($composerFocused)
                    .accessibilityLabel("이 기기에 저장할 샘플 대화 메시지")
                Button {
                    if store.send(draft, id: conversationID) { draft = "" }
                } label: {
                    Image(systemName: "arrow.up").font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(canSend ? Color.naldamAccent : Color.naldamSecondary.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain).disabled(!canSend)
                .accessibilityLabel("메시지 기기에 저장")
            }
            Text("실제 전송 없이 이 기기에만 저장돼요")
                .font(.caption2).foregroundStyle(Color.naldamSecondary)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
        .background(Color.naldamEnvelope.ignoresSafeArea(edges: .bottom))
    }
}

private struct ChatMessageBubble: View {
    let message: LocalMessage
    let person: SamplePerson
    private var isMine: Bool { message.origin == .me }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMine { Spacer(minLength: 34) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                Text(message.body)
                    .font(.body).lineSpacing(4).foregroundStyle(isMine ? Color.naldamPaper : Color.naldamInk)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(isMine ? Color.naldamAccent : Color.naldamPaper,
                                in: UnevenRoundedRectangle(topLeadingRadius: isMine ? 20 : 4, bottomLeadingRadius: 20,
                                                           bottomTrailingRadius: 20, topTrailingRadius: isMine ? 4 : 20))
                    .overlay { UnevenRoundedRectangle(topLeadingRadius: isMine ? 20 : 4, bottomLeadingRadius: 20,
                                                      bottomTrailingRadius: 20, topTrailingRadius: isMine ? 4 : 20)
                        .stroke(Color.naldamLine.opacity(isMine ? 0 : 0.7), lineWidth: 0.8) }
                HStack(spacing: 5) {
                    Text(message.createdAt, format: .dateTime.month().day().hour().minute())
                    Text(isMine ? "기기 저장" : "샘플 메시지")
                }.font(.caption2).foregroundStyle(Color.naldamSecondary)
            }
            if !isMine { Spacer(minLength: 24) }
        }
        .accessibilityElement(children: .combine)
    }
}
