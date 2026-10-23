import SwiftUI
import SwiftData

enum RecentJournalEntries {
    static func select(from entries: [QuizEntry], today: Date = .now) -> [QuizEntry] {
        let calendar = QuizDateHelper.calendar
        let lastDay = calendar.startOfDay(for: today)
        var seen = Set<Date>()
        return Array(entries.filter {
            !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && calendar.startOfDay(for: $0.date) <= lastDay
        }.sorted {
            let lhs = calendar.startOfDay(for: $0.date), rhs = calendar.startOfDay(for: $1.date)
            return lhs == rhs ? $0.updatedAt > $1.updatedAt : lhs > rhs
        }.filter { seen.insert(calendar.startOfDay(for: $0.date)).inserted }.prefix(5))
    }
}

struct RecentJournalSection: View {
    let entries: [QuizEntry]
    var today: Date = .now
    private var recentEntries: [QuizEntry] { RecentJournalEntries.select(from: entries, today: today) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("다시 꺼내보는 나").font(.subheadline.weight(.semibold))
                Spacer(minLength: 6)
                NavigationLink { JournalHistoryView() } label: {
                    Text("모두 보기").font(.caption).foregroundStyle(Color.naldamSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain).accessibilityIdentifier("home.history")
            }
            if recentEntries.isEmpty {
                Text("하루를 담으면, 이곳에 차곡차곡 쌓여요.")
                    .font(.footnote).foregroundStyle(Color.naldamSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 16))
            }
            ForEach(Array(recentEntries.enumerated()), id: \.element.persistentModelID) { index, entry in
                NavigationLink { QuizPageView(date: entry.date) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 18, weight: .light)).foregroundStyle(Color.naldamAccent)
                            .frame(width: 34, height: 39)
                            .background(Color.naldamSoft, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.answer).font(.subheadline).foregroundStyle(Color.naldamInk).lineLimit(2)
                            Text(entry.date, format: .dateTime.month().day())
                                .font(.caption).foregroundStyle(Color.naldamSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.naldamSecondary)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.naldamLine, lineWidth: 0.8))
                }
                .buttonStyle(.plain).accessibilityIdentifier("home.recent.\(index)")
            }
        }
        .foregroundStyle(Color.naldamInk)
    }
}
