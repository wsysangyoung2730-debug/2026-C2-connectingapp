import SwiftUI
import SwiftData

struct MainHomeView: View {
    var body: some View { NaldamTabRoot() }
}

struct NaldamHomeView: View {
    @Query(sort: \QuizEntry.date, order: .reverse) private var entries: [QuizEntry]
    @Query private var drafts: [JournalDraft]
    @AppStorage("profileName") private var profileName = "나"
    @State private var isBackgroundDimmed = false
    @State private var isInterestExpanded = false
    @State private var showProfile = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var savedEntries: [QuizEntry] {
        entries.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let today = Calendar.current.startOfDay(for: timeline.date)
            let entry = savedEntries.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
            let draft = drafts.first { Calendar.current.isDate($0.date, inSameDayAs: today) && !$0.answer.isEmpty }
            ZStack(alignment: .bottom) {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        VStack(alignment: .leading, spacing: 10) {
                            Text(today.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ko_KR"))))
                                .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                            Text(entry == nil ? "오늘의 나를\n담아볼까요?" : "오늘도 나를\n한 장 담았어요.")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.naldamInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        NavigationLink { QuizPageView(date: today) } label: {
                            TodayPromptCard(question: entry?.question ?? draft?.question ?? DailyQuestionProvider.question(for: today),
                                            buttonTitle: draft != nil ? "이어서 기록하기" : (entry == nil ? "오늘 기록하기" : "오늘의 기록 보기"),
                                            hasSavedEntry: entry != nil)
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("home.today")
                        WeeklyRecordCard(entries: savedEntries, today: today)
                        NavigationLink { JournalHistoryView() } label: {
                            HStack(spacing: 14) {
                                NaldamLogo(size: 32).padding(12)
                                    .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 15))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("다시 꺼내보는 나").font(.headline).foregroundStyle(Color.naldamInk)
                                    Text(savedEntries.first?.answer ?? "첫 기록부터 차곡차곡 모아보세요")
                                        .font(.subheadline).foregroundStyle(Color.naldamSecondary).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").foregroundStyle(Color.naldamSecondary)
                            }.naldamCard()
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("home.history")
                    }
                    .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 275)
                    .frame(maxWidth: 650).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden).allowsHitTesting(!isBackgroundDimmed)
                .accessibilityIdentifier("home.scroll")
                .accessibilityHidden(isBackgroundDimmed)
                if isBackgroundDimmed {
                    Color.naldamInk.opacity(0.24).ignoresSafeArea()
                        .onTapGesture { closeInterests() }
                        .accessibilityLabel("관심사 닫기").accessibilityAddTraits(.isButton)
                        .accessibilityAction { closeInterests() }.transition(.opacity)
                }
                InterestBottomSheet(isBackgroundDimmed: $isBackgroundDimmed,
                                    isExpanded: $isInterestExpanded)
                    .frame(maxWidth: 650)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(isInterestExpanded ? .hidden : .automatic, for: .tabBar)
        .sheet(isPresented: $showProfile) { NaldamProfileView() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            NaldamLogo(size: 30)
            Text("날담").font(.title.weight(.bold)).foregroundStyle(Color.naldamInk)
            Spacer()
            Button { showProfile = true } label: { NaldamAvatar(name: profileName) }
                .accessibilityLabel("내 프로필과 앱 안내").accessibilityIdentifier("home.profile")
        }.padding(.bottom, 12)
    }

    private func closeInterests() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { isBackgroundDimmed = false }
    }
}
