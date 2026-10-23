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
                NaldamEnvelopeBackground()
                GeometryReader { geometry in
                    let reservedHeight = InterestLayoutHelper.height(for: .collapsed, screenHeight: geometry.size.height) + 18
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            header
                            Text(today.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ko_KR"))))
                                .font(.caption).foregroundStyle(Color.naldamSecondary)
                            NavigationLink { QuizPageView(date: today) } label: {
                                TodayPromptCard(question: entry?.question ?? draft?.question ?? DailyQuestionProvider.question(for: today),
                                                buttonTitle: draft != nil ? "이어서 기록하기" : (entry == nil ? "오늘 기록하기" : "오늘의 기록 보기"),
                                                hasSavedEntry: entry != nil)
                            }
                            .buttonStyle(.plain).accessibilityIdentifier("home.today")
                            WeeklyRecordCard(entries: savedEntries, today: today)
                            RecentJournalSection(entries: savedEntries, today: today)
                        }
                        .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 16)
                        .frame(maxWidth: 650).frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden).allowsHitTesting(!isBackgroundDimmed)
                    // Keep later records out of the curved paper's transparent corners.
                    .frame(height: max(0, geometry.size.height - reservedHeight))
                    .clipped()
                    .accessibilityIdentifier("home.scroll")
                    .accessibilityHidden(isBackgroundDimmed)
                }
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
        .naldamTabBarHidden(isInterestExpanded)
        .sheet(isPresented: $showProfile) { NaldamProfileView() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            NaldamLogo(size: 30)
            Text("날담").font(.title.weight(.bold)).foregroundStyle(Color.naldamInk)
            Spacer()
            Button { showProfile = true } label: { NaldamProfilePhoto(width: 36, height: 38).frame(minWidth: 44, minHeight: 44) }
                .accessibilityLabel("내 프로필과 앱 안내").accessibilityIdentifier("home.profile")
        }
    }

    private func closeInterests() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { isBackgroundDimmed = false }
    }
}
