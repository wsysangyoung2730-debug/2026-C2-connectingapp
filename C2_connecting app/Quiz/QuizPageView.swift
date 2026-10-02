import SwiftUI
import SwiftData

struct QuizPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isAnswerFocused: Bool

    private let date: Date
    @State private var answer = ""
    @State private var question = ""
    @State private var savedAnswer: String?
    @State private var lastPersistedAnswer = ""
    @State private var hasLoaded = false
    @State private var savedFeedback = false
    @State private var showDeleteConfirmation = false
    @State private var showDiscardConfirmation = false
    @State private var showPrivacyInfo = false
    @State private var errorMessage: String?
    @State private var draftSaveFailed = false

    init(date: Date = Date()) {
        self.date = QuizDateHelper.startOfDay(date)
    }

    private var isFuture: Bool { QuizDateHelper.isFuture(date) }
    private var isToday: Bool { QuizDateHelper.isSameDay(date, Date()) }
    private var hasChanges: Bool { answer != (savedAnswer ?? "") }
    private var canSave: Bool {
        hasLoaded && !isFuture && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (savedAnswer == nil || hasChanges)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                dateHeader
                if isFuture {
                    NaldamEmptyState(symbol: "calendar", title: "아직 오지 않은 하루예요", message: "오늘의 이야기를 먼저 남겨보세요.")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isToday ? "오늘의 질문" : "그날의 질문")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.naldamAccent)
                        Text(question.isEmpty ? DailyQuestionProvider.question(for: date) : question)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.naldamInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    writingPaper
                    privacyRow
                    Button(action: saveRecord) {
                        HStack {
                            Spacer(minLength: 0)
                            Text(savedFeedback ? "기록을 저장했어요" : (savedAnswer == nil ? "기록 저장" : (hasChanges ? "수정 내용 저장" : "저장된 기록")))
                            Spacer(minLength: 0)
                            Image(systemName: savedFeedback || (!canSave && savedAnswer != nil) ? "checkmark" : "arrow.right")
                        }
                    }
                    .buttonStyle(NaldamPrimaryButtonStyle())
                    .disabled(!canSave)
                    .accessibilityIdentifier("journal.save")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground)
        .navigationTitle(isToday ? "오늘의 기록" : "그날의 기록")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if persistDraftIfNeeded() { dismiss() }
                } label: {
                    Label("뒤로", systemImage: "chevron.left")
                }
                .tint(Color.naldamInk)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if hasChanges {
                        Button("임시 작성 내용 지우기", systemImage: "arrow.uturn.backward") { showDiscardConfirmation = true }
                    }
                    if savedAnswer != nil {
                        Button("기록 삭제", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
                    }
                    Button("기록 보관 안내", systemImage: "lock") { showPrivacyInfo = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("기록 메뉴")
                .tint(Color.naldamInk)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { isAnswerFocused = false }
            }
        }
        .onAppear(perform: loadRecord)
        .onChange(of: answer) { _, _ in
            guard hasLoaded, answer != lastPersistedAnswer else { return }
            savedFeedback = false
            _ = persistDraftIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { _ = persistDraftIfNeeded() }
        }
        .onDisappear { _ = persistDraftIfNeeded() }
        .alert("기록을 삭제할까요?", isPresented: $showDeleteConfirmation) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive, action: deleteRecord)
        } message: {
            Text("이 날짜의 기록과 임시 작성 내용이 이 기기에서 삭제돼요. 삭제한 내용은 되돌릴 수 없어요.")
        }
        .alert("임시 작성을 지울까요?", isPresented: $showDiscardConfirmation) {
            Button("취소", role: .cancel) { }
            Button("지우기", role: .destructive, action: discardDraft)
        } message: {
            Text(savedAnswer == nil ? "아직 저장하지 않은 작성 내용이 지워져요." : "마지막으로 저장한 기록으로 돌아가요. 저장된 기록은 지워지지 않아요.")
        }
        .alert("나만 보는 기록", isPresented: $showPrivacyInfo) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("기록은 이 기기에 저장돼요. 발견이나 대화에 자동으로 공유되지 않아요. 앱을 삭제하면 기록이 사라질 수 있으니 소중한 기록은 별도로 보관해주세요.")
        }
        .alert("저장을 확인해주세요", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(QuizDateHelper.fullDateString(date)) \(QuizDateHelper.weekdaySymbol(for: date))요일")
                .font(.subheadline)
                .foregroundStyle(Color.naldamSecondary)
            Label("나만 보기", systemImage: "lock.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.naldamSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.naldamLine.opacity(0.55), in: Capsule())
        }
    }

    private var writingPaper: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                if answer.isEmpty {
                    Text("짧은 한 줄도 괜찮아요.\n지금 떠오르는 마음을 담아보세요.")
                        .font(.body)
                        .lineSpacing(7)
                        .foregroundStyle(Color.naldamSecondary.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $answer)
                    .font(.body)
                    .lineSpacing(7)
                    .foregroundStyle(Color.naldamInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 260)
                    .focused($isAnswerFocused)
                    .disabled(!hasLoaded)
                    .accessibilityLabel("질문에 대한 나의 답변")
                    .accessibilityIdentifier("journal.answer")
            }
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: draftSaveFailed ? "exclamationmark.circle" : "checkmark.circle")
                Text(draftSaveFailed ? "임시 저장하지 못했어요. 다시 시도해주세요." : (hasChanges ? "이 기기에 임시 저장됐어요" : "작성 중인 내용은 이 기기에 임시 저장돼요"))
            }
            .font(.caption)
            .foregroundStyle(draftSaveFailed ? Color.naldamAccent : Color.naldamSecondary)
            .accessibilityIdentifier("journal.draftStatus")
            if draftSaveFailed {
                Button("임시 저장 다시 시도") { _ = persistDraftIfNeeded() }
                    .font(.subheadline.weight(.semibold))
                    .tint(Color.naldamAccent)
            }
        }
        .padding(20)
        .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .topTrailing) {
            JournalPaperFold()
                .fill(Color.naldamLine.opacity(0.75))
                .frame(width: 28, height: 28)
                .padding(1)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.naldamLine.opacity(0.7), lineWidth: 1))
        .shadow(color: Color.naldamInk.opacity(0.025), radius: 14, y: 7)
    }

    private var privacyRow: some View {
        Button { showPrivacyInfo = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(Color.naldamSecondary)
                    .frame(width: 42, height: 46)
                    .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("기록 보관").font(.caption).foregroundStyle(Color.naldamSecondary)
                    Text("나만 보기 · 이 기기에 저장").font(.subheadline.weight(.medium)).foregroundStyle(Color.naldamInk)
                }
                Spacer(minLength: 0)
                Image(systemName: "info.circle").foregroundStyle(Color.naldamSecondary)
            }
            .naldamCard()
        }
        .buttonStyle(.plain)
    }

    private func loadRecord() {
        guard !hasLoaded else { return }
        do {
            let snapshot = try JournalPersistence.load(date: date, in: modelContext)
            savedAnswer = snapshot.savedAnswer
            question = snapshot.savedQuestion ?? snapshot.draftQuestion ?? DailyQuestionProvider.question(for: date)
            let restoredAnswer = snapshot.draftAnswer ?? snapshot.savedAnswer ?? ""
            lastPersistedAnswer = restoredAnswer
            answer = restoredAnswer
            hasLoaded = true
        } catch {
            errorMessage = "기록을 불러오지 못했어요. 뒤로 돌아간 뒤 다시 열어주세요.\n\(error.localizedDescription)"
        }
    }

    @discardableResult
    private func persistDraftIfNeeded() -> Bool {
        guard hasLoaded, !isFuture, answer != lastPersistedAnswer else { return true }
        do {
            try JournalPersistence.saveDraft(answer: answer, question: question, date: date, in: modelContext)
            lastPersistedAnswer = answer
            draftSaveFailed = false
            return true
        } catch {
            if !draftSaveFailed {
                errorMessage = "임시 저장에 실패했어요. 작성 내용은 화면에 남아 있어요. 앱을 닫기 전에 다시 저장해주세요.\n\(error.localizedDescription)"
            }
            draftSaveFailed = true
            return false
        }
    }

    private func saveRecord() {
        do {
            try JournalPersistence.saveRecord(answer: answer, question: question, date: date, in: modelContext)
            let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            savedAnswer = trimmed
            lastPersistedAnswer = trimmed
            answer = trimmed
            draftSaveFailed = false
            savedFeedback = true
            isAnswerFocused = false
        } catch {
            errorMessage = "기록을 저장하지 못했어요. 작성 내용은 지워지지 않았으니 다시 시도해주세요.\n\(error.localizedDescription)"
        }
    }

    private func discardDraft() {
        do {
            try JournalPersistence.discardDraft(date: date, in: modelContext)
            let restoredAnswer = savedAnswer ?? ""
            lastPersistedAnswer = restoredAnswer
            answer = restoredAnswer
            draftSaveFailed = false
            savedFeedback = false
        } catch {
            errorMessage = "임시 작성을 지우지 못했어요.\n\(error.localizedDescription)"
        }
    }

    private func deleteRecord() {
        do {
            try JournalPersistence.deleteRecord(date: date, in: modelContext)
            hasLoaded = false
            lastPersistedAnswer = ""
            answer = ""
            dismiss()
        } catch {
            errorMessage = "기록을 삭제하지 못했어요. 다시 시도해주세요.\n\(error.localizedDescription)"
        }
    }
}

private struct JournalPaperFold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height), control: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.closeSubpath()
        return path
    }
}

#Preview {
    NavigationStack { QuizPageView() }
        .modelContainer(for: [QuizEntry.self, JournalDraft.self], inMemory: true)
}
