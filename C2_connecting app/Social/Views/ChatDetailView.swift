import SwiftUI

struct ChatDetailView: View {
    let conversationID: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LiveChatStore.shared
    @State private var draft = ""
    @State private var lastPersistedDraft = ""
    @State private var hasLoadedDraft = false
    @State private var draftOwnerID: String?
    @State private var chatToken: UUID?
    @State private var showingBlockConfirmation = false
    @State private var showingLeaveConfirmation = false
    @State private var reportTarget: ContentReportTarget?
    @FocusState private var composerFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var loadingOlder = false
    @State private var isVisible = false
    @State private var managing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var suggestedQuestion: String { DailyQuestionProvider.question(for: .now) }

    private var conversation: ChatRoom? { store.room(id: conversationID) }
    private var canCompose: Bool {
        guard let conversation else { return false }
        return conversation.status == .active && !conversation.isArchived && !conversation.isBlocked
    }
    private var canSend: Bool {
        canCompose && ChatValidation.message(draft) != nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    SocialStorageWarning(message: store.errorMessage)
                    if let conversation {
                        let person = conversation.person
                        storyContext(person)
                        if store.messages.isEmpty {
                            NaldamEmptyState(symbol: "bubble.left", title: "첫 이야기를 남겨 보세요", message: "궁금했던 문장이나 공통 관심사로 시작해도 좋아요.")
                        }
                        if store.hasOlderMessages {
                            Button {
                                loadingOlder = true
                                Task { await store.loadOlderMessages(); loadingOlder = false }
                            } label: {
                                if loadingOlder { ProgressView() } else { Text("이전 메시지 보기") }
                            }.font(.footnote).frame(maxWidth: .infinity, minHeight: 44).disabled(loadingOlder)
                        }
                        ForEach(store.messages) { message in
                            ChatMessageBubble(message: message) { store.retry(messageID: message.id) }
                                .contextMenu {
                                    if !message.isMine {
                                        Button("이 메시지 신고", systemImage: "flag", role: .destructive) {
                                            reportTarget = ContentReportTarget(personID: person.id, personName: person.name,
                                                roomID: conversationID, messageID: message.id)
                                        }
                                    }
                                }
                                .id(message.id)
                        }
                        if canCompose && store.messages.count < 4 && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            questionSuggestion
                        }
                    } else {
                        NaldamEmptyState(symbol: "bubble.left", title: "대화를 찾을 수 없어요", message: "뒤로 돌아가 대화 목록을 확인해 주세요.")
                    }
                    Color.clear.frame(height: 1).id("conversation-bottom")
                }.padding(18).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.messages.last?.id) { _, _ in
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
        .navigationTitle(conversation?.person.name ?? "대화")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .naldamTabBarHidden()
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation?.person.name ?? "대화").font(.headline)
                    Text("두 사람의 이야기").font(.caption2).foregroundStyle(Color.naldamSecondary)
                }.accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("신고하기", systemImage: "flag", role: .destructive) {
                        if let person = conversation?.person {
                            reportTarget = ContentReportTarget(personID: person.id, personName: person.name, roomID: conversationID)
                        }
                    }
                    Button("프로필 차단", systemImage: "hand.raised", role: .destructive) { showingBlockConfirmation = true }
                    Button("대화 숨기기", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { showingLeaveConfirmation = true }
                } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("대화 관리")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { composerFocused = false }
            }
        }
        .onAppear {
            isVisible = true
            draftOwnerID = store.currentUserID
            chatToken = store.openChat(id: conversationID)
            // Another instance of this conversation may have changed its draft while
            // this screen was behind a story/request detail. Never restore stale text.
            // A locally edited draft that failed to save is the one exception.
            if !hasLoadedDraft || draft == lastPersistedDraft {
                let savedDraft = store.draft(for: conversationID)
                lastPersistedDraft = savedDraft
                draft = savedDraft
                hasLoadedDraft = true
            }
            store.markRead(id: conversationID)
        }
        .onChange(of: draft) { _, _ in persistDraftIfNeeded() }
        .onDisappear {
            isVisible = false
            composerFocused = false
            persistDraftIfNeeded()
            store.closeChat(token: chatToken)
            chatToken = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isVisible { store.markRead(id: conversationID) }
        }
        .confirmationDialog("이 프로필을 차단할까요?", isPresented: $showingBlockConfirmation, titleVisibility: .visible) {
            Button("차단", role: .destructive) {
                managing = true
                Task {
                    if await store.setBlocked(true, id: conversationID) { dismiss() }
                    managing = false
                }
            }
        } message: {
            Text("새 메시지를 주고받을 수 없고 발견과 대화 목록에서 숨겨져요. 기존 메시지는 지우지 않으며, 대화 탭의 차단 관리에서 해제할 수 있어요.")
        }
        .confirmationDialog("이 대화를 목록에서 숨길까요?", isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
            Button("대화 숨기기", role: .destructive) {
                managing = true
                Task {
                    if await store.archive(id: conversationID) { dismiss() }
                    managing = false
                }
            }
        } message: {
            Text("내 목록에서만 숨겨져요. 발견에서 같은 사람의 대화를 다시 열 수 있어요.")
        }
        .disabled(managing)
        .sheet(item: $reportTarget) { ContentReportView(target: $0) }
    }

    private func persistDraftIfNeeded() {
        guard hasLoadedDraft, draftOwnerID != nil, draftOwnerID == store.currentUserID,
              draft != lastPersistedDraft else { return }
        if store.saveDraft(draft, in: conversationID) { lastPersistedDraft = draft }
    }

    private func storyContext(_ person: ChatProfile) -> some View {
        let shared = person.sharedInterests(with: store.publishedProfile?.interests ?? [])
        return VStack(spacing: 8) {
            Image(systemName: "leaf").font(.system(size: 24, weight: .light)).foregroundStyle(Color.naldamAccent)
            Text(shared.isEmpty ? "가벼운 안부로 만나는 사이." : "\(shared.joined(separator: " · "))으로 만난 사이.")
                .font(.subheadline).foregroundStyle(Color.naldamAccent)
                .multilineTextAlignment(.center)
            Text("가벼운 안부부터 나눠보세요.")
                .font(.caption).foregroundStyle(Color.naldamSecondary)
            NavigationLink { PublicPersonView(person: person) } label: {
                Text("공개 프로필 보기").font(.caption).frame(minHeight: 36)
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
            if draft.utf16.count > 2_000 {
                Text("메시지가 너무 길어요. 내용을 조금 줄여 주세요.")
                    .font(.caption).foregroundStyle(Color.naldamAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("따뜻한 한마디를 남겨보세요", text: $draft, axis: .vertical)
                    .font(.body).lineLimit(1...5)
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(Color.naldamPaper.opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
                    .focused($composerFocused)
                    .accessibilityLabel("대화 메시지")
                Button {
                    if store.send(draft, in: conversationID) { draft = "" }
                } label: {
                    Image(systemName: "arrow.up").font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(canSend ? Color.naldamAccent : Color.naldamSecondary.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain).disabled(!canSend)
                .accessibilityLabel("메시지 보내기")
            }
            Text("신고한 내용은 운영자가 확인할 수 있어요")
                .font(.caption2).foregroundStyle(Color.naldamSecondary)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
        .background(Color.naldamEnvelope.ignoresSafeArea(edges: .bottom))
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage
    var retry: () -> Void
    private var isMine: Bool { message.isMine }
    private var deliveryLabel: String {
        switch message.delivery {
        case .sending: "전송 중"
        case .sent: "전송됨"
        case .failed: "전송 실패"
        }
    }

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
                    if isMine { Text(deliveryLabel) }
                }.font(.caption2).foregroundStyle(Color.naldamSecondary)
                if isMine && message.delivery == .failed {
                    if let error = message.error {
                        Text(error).font(.caption).foregroundStyle(Color.naldamSecondary)
                    }
                    Button("다시 보내기", action: retry)
                        .font(.caption.weight(.semibold)).frame(minHeight: 44)
                        .accessibilityIdentifier("chat.retry.\(message.id)")
                }
            }
            if !isMine { Spacer(minLength: 24) }
        }.accessibilityElement(children: .contain)
    }
}
