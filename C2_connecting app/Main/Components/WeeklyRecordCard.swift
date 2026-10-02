import SwiftUI

struct WeeklyRecordCard: View {
    let entries: [QuizEntry]
    var today = Date()
    private var days: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let offset = (calendar.component(.weekday, from: start) + 5) % 7
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0 - offset, to: start) }
    }
    private func hasRecord(_ date: Date) -> Bool {
        entries.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    private var count: Int { days.filter(hasRecord).count }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            NavigationLink { JournalHistoryView() } label: {
                HStack {
                    Text(count == 0 ? "이번 주, 나를 위한 한 줄" : "이번 주, \(count)번의 기록").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.foregroundStyle(Color.naldamInk)
            }.buttonStyle(.plain)
            HStack(spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                    let recorded = hasRecord(date)
                    let future = date > Calendar.current.startOfDay(for: today)
                    let isToday = Calendar.current.isDate(date, inSameDayAs: today)
                    NavigationLink { QuizPageView(date: date) } label: {
                        VStack(spacing: 10) {
                            Text(["월", "화", "수", "목", "금", "토", "일"][index]).font(.caption)
                            ZStack {
                                Circle().fill(recorded ? Color.naldamAccent : Color.clear)
                                Circle().stroke(recorded ? Color.clear : (isToday ? Color.naldamAccent : Color.naldamLine), lineWidth: isToday ? 2 : 1.5)
                                if recorded {
                                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                                }
                            }.frame(width: 26, height: 26)
                        }
                        .foregroundStyle(future ? Color.naldamLine : Color.naldamSecondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(isToday ? Color.appBackground : .clear, in: Capsule()).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(future)
                    .accessibilityLabel("\(date.formatted(.dateTime.month().day())) \(recorded ? "기록 완료" : future ? "아직 오지 않은 날" : "기록 없음")")
                }
            }
        }.naldamCard()
    }
}
