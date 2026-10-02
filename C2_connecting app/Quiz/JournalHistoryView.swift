import SwiftUI
import SwiftData

struct JournalHistoryView: View {
    @Query(sort: \QuizEntry.date, order: .reverse) private var entries: [QuizEntry]
    @Query(sort: \JournalDraft.updatedAt, order: .reverse) private var drafts: [JournalDraft]
    @State private var visibleMonth = Date()
    @State private var selectedDate: Date?
    @State private var searchText = ""

    private var search: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var savedEntries: [QuizEntry] {
        entries.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    private var displayedEntries: [QuizEntry] {
        savedEntries.filter { entry in
            if !search.isEmpty {
                return entry.answer.localizedCaseInsensitiveContains(search) || entry.question.localizedCaseInsensitiveContains(search)
            }
            if let selectedDate { return QuizDateHelper.isSameDay(entry.date, selectedDate) }
            return QuizDateHelper.calendar.isDate(entry.date, equalTo: visibleMonth, toGranularity: .month)
        }
    }
    private var unfinishedDrafts: [JournalDraft] {
        drafts.filter { draft in
            guard !draft.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !savedEntries.contains(where: { QuizDateHelper.isSameDay($0.date, draft.date) }) else { return false }
            if !search.isEmpty {
                return draft.answer.localizedCaseInsensitiveContains(search) || draft.question.localizedCaseInsensitiveContains(search)
            }
            if let selectedDate { return QuizDateHelper.isSameDay(draft.date, selectedDate) }
            return QuizDateHelper.calendar.isDate(draft.date, equalTo: visibleMonth, toGranularity: .month)
        }
    }
    private var sectionTitle: String {
        if !search.isEmpty { return "찾은 기록" }
        if let selectedDate { return QuizDateHelper.fullDateString(selectedDate) }
        return "이번 달에 담은 이야기"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if search.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("작은 하루가 모여,\n나의 이야기가 돼요.")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.naldamInk)
                        Text("지금까지 \(savedEntries.count)개의 기록을 담았어요")
                            .font(.subheadline)
                            .foregroundStyle(Color.naldamSecondary)
                    }
                    JournalMonthCalendar(
                        visibleMonth: $visibleMonth,
                        selectedDate: $selectedDate,
                        recordedDates: Set(savedEntries.map { QuizDateHelper.startOfDay($0.date) }),
                        draftDates: Set(drafts.map { QuizDateHelper.startOfDay($0.date) })
                    )
                }

                if !unfinishedDrafts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        NaldamSectionHeading(title: "이어서 쓰기")
                        ForEach(unfinishedDrafts) { draft in
                            NavigationLink {
                                QuizPageView(date: draft.date)
                            } label: {
                                draftCard(draft)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        NaldamSectionHeading(title: sectionTitle)
                        Spacer(minLength: 0)
                        if selectedDate != nil && search.isEmpty {
                            Button("월 전체") { selectedDate = nil }
                                .font(.subheadline.weight(.medium))
                                .tint(Color.naldamAccent)
                        }
                    }
                    if displayedEntries.isEmpty {
                        emptyRecords
                    } else {
                        ForEach(displayedEntries) { entry in
                            NavigationLink {
                                QuizPageView(date: entry.date)
                            } label: {
                                recordCard(entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle("나의 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .searchable(text: $searchText, prompt: "질문이나 기록 내용 찾기")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { QuizPageView() } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("오늘의 기록 쓰기")
                .tint(Color.naldamAccent)
            }
        }
    }

    private var emptyRecords: some View {
        VStack(spacing: 18) {
            NaldamEmptyState(
                symbol: search.isEmpty ? "book.closed" : "magnifyingglass",
                title: search.isEmpty ? "아직 담긴 기록이 없어요" : "찾는 기록이 없어요",
                message: search.isEmpty ? "완벽한 하루가 아니어도 좋아요.\n떠오르는 한 순간부터 남겨보세요." : "다른 단어나 짧은 문장으로 찾아보세요."
            )
            if search.isEmpty {
                NavigationLink {
                    QuizPageView(date: selectedDate ?? Date())
                } label: {
                    Label(selectedDate == nil ? "오늘의 기록 쓰기" : "이날의 기록 쓰기", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NaldamPrimaryButtonStyle())
            }
        }
    }

    private func recordCard(_ entry: QuizEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(QuizDateHelper.fullDateString(entry.date))
                    .font(.caption.weight(.medium))
                Spacer(minLength: 0)
                Image(systemName: "lock")
                    .accessibilityLabel("나만 보는 기록")
            }
            .foregroundStyle(Color.naldamSecondary)
            Text(entry.question)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.naldamInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(entry.answer)
                .font(.subheadline)
                .foregroundStyle(Color.naldamSecondary)
                .lineSpacing(4)
                .lineLimit(3)
            HStack {
                if drafts.contains(where: { QuizDateHelper.isSameDay($0.date, entry.date) }) {
                    Text("임시 작성 내용이 있어요")
                } else {
                    Text("다시 꺼내보기")
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.naldamAccent)
        }
        .naldamCard()
        .accessibilityElement(children: .combine)
    }

    private func draftCard(_ draft: JournalDraft) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "pencil.line")
                .font(.title3)
                .foregroundStyle(Color.naldamAccent)
                .frame(width: 40, height: 40)
                .background(Color.naldamAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 7) {
                Text(QuizDateHelper.fullDateString(draft.date))
                    .font(.caption)
                    .foregroundStyle(Color.naldamSecondary)
                Text(draft.answer)
                    .font(.subheadline)
                    .foregroundStyle(Color.naldamInk)
                    .lineLimit(2)
                Text("임시 저장 · 이어서 쓰기")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.naldamAccent)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.naldamSecondary)
                .padding(.top, 14)
        }
        .naldamCard()
        .accessibilityElement(children: .combine)
    }
}

private struct JournalMonthCalendar: View {
    @Binding var visibleMonth: Date
    @Binding var selectedDate: Date?
    var recordedDates: Set<Date>
    var draftDates: Set<Date>

    private var canMoveForward: Bool {
        guard let nextMonth = QuizDateHelper.calendar.date(byAdding: .month, value: 1, to: visibleMonth),
              let currentMonth = QuizDateHelper.calendar.dateInterval(of: .month, for: Date()) else { return false }
        return nextMonth < currentMonth.end
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("이전 달")
                Spacer(minLength: 0)
                Text(QuizDateHelper.yearMonthTitle(for: visibleMonth))
                    .font(.headline)
                    .foregroundStyle(Color.naldamInk)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled(!canMoveForward)
                .accessibilityLabel("다음 달")
            }
            .tint(Color.naldamSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 5) {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(Color.naldamSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 7)
                }
                let dates = QuizDateHelper.monthDates(containing: visibleMonth)
                ForEach(dates.indices, id: \.self) { index in
                    if let date = dates[index] {
                        dayButton(date)
                    } else {
                        Color.clear.frame(height: 44).accessibilityHidden(true)
                    }
                }
            }
            HStack(spacing: 14) {
                Label("저장한 기록", systemImage: "circle.fill")
                    .foregroundStyle(Color.naldamAccent)
                Label("임시 작성", systemImage: "circle")
                    .foregroundStyle(Color.naldamSecondary)
                Spacer(minLength: 0)
                Button("오늘") {
                    visibleMonth = Date()
                    selectedDate = QuizDateHelper.startOfDay(Date())
                }
                .fontWeight(.medium)
                .tint(Color.naldamAccent)
            }
            .font(.caption2)
            .padding(.horizontal, 4)
        }
        .naldamCard()
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = selectedDate.map { QuizDateHelper.isSameDay($0, date) } ?? false
        let isToday = QuizDateHelper.isSameDay(date, Date())
        let isFuture = QuizDateHelper.isFuture(date)
        let hasRecord = recordedDates.contains(QuizDateHelper.startOfDay(date))
        let hasDraft = draftDates.contains(QuizDateHelper.startOfDay(date))
        return Button {
            selectedDate = isSelected ? nil : date
        } label: {
            VStack(spacing: 3) {
                Text("\(QuizDateHelper.calendar.component(.day, from: date))")
                    .font(.callout.weight(isSelected || isToday ? .semibold : .regular))
                Image(systemName: hasRecord ? "circle.fill" : "circle")
                    .font(.system(size: 4))
                    .opacity(hasRecord || hasDraft ? 1 : 0)
            }
            .foregroundStyle(isSelected ? Color.white : (isFuture ? Color.naldamSecondary.opacity(0.35) : (isToday ? Color.naldamAccent : Color.naldamInk)))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12).fill(Color.naldamAccent)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.naldamAccent.opacity(0.45), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel("\(QuizDateHelper.fullDateString(date)), \(hasRecord ? "저장한 기록 있음" : hasDraft ? "임시 작성 있음" : "기록 없음")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func moveMonth(_ offset: Int) {
        guard let monthStart = QuizDateHelper.calendar.dateInterval(of: .month, for: visibleMonth)?.start,
              let nextMonth = QuizDateHelper.calendar.date(byAdding: .month, value: offset, to: monthStart) else { return }
        selectedDate = nil
        visibleMonth = nextMonth
    }
}

#Preview {
    NavigationStack { JournalHistoryView() }
        .modelContainer(for: [QuizEntry.self, JournalDraft.self], inMemory: true)
}
