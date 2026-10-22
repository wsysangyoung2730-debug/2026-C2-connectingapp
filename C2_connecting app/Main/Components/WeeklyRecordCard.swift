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
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink { JournalHistoryView() } label: {
                HStack {
                    Text("이번 주").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(count == 0 ? "하루를 하나씩 담아봐요" : "\(count)번의 하루를 담았어요")
                        .font(.caption).foregroundStyle(Color.naldamSecondary)
                }.foregroundStyle(Color.naldamInk)
            }.buttonStyle(.plain)
            HStack(spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                    let recorded = hasRecord(date)
                    let future = date > Calendar.current.startOfDay(for: today)
                    let isToday = Calendar.current.isDate(date, inSameDayAs: today)
                    NavigationLink { QuizPageView(date: date) } label: {
                        VStack(spacing: 5) {
                            Text(["월", "화", "수", "목", "금", "토", "일"][index]).font(.caption)
                            ZStack {
                                Circle().fill(isToday ? Color.naldamAccent : (recorded ? Color.naldamSoft : Color.clear))
                                if recorded && !isToday {
                                    Image(systemName: "checkmark").font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.naldamAccent)
                                } else {
                                    Text(date.formatted(.dateTime.day()))
                                        .font(.subheadline.weight(isToday ? .semibold : .medium).monospacedDigit())
                                        .foregroundStyle(isToday ? Color.naldamPaper : Color.naldamInk)
                                }
                            }.frame(width: 30, height: 30)
                        }
                        .foregroundStyle(isToday ? Color.naldamAccent : Color.naldamSecondary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(isToday ? Color.naldamSoft : .clear, in: Capsule()).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(future)
                    .accessibilityLabel("\(date.formatted(.dateTime.month().day())) \(recorded ? "기록 완료" : future ? "아직 오지 않은 날" : "기록 없음")")
                }
            }
        }
        .padding(11)
        .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.naldamLine, lineWidth: 0.8))
    }
}
