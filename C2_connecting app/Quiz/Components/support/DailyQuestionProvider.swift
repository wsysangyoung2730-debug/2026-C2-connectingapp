import Foundation

enum DailyQuestionProvider {
    // Freeze this order and seed: changing them would reassign unsaved calendar dates.
    private static let schedule: [String] = {
        var questions = DailyQuestionCatalog.questions
        var random = ScheduleRandom(state: 0x4E41_4C44_414D)
        for index in stride(from: questions.count - 1, through: 1, by: -1) {
            let other = Int(random.next() % UInt64(index + 1))
            questions.swapAt(index, other)
        }
        return questions
    }()

    /// One stable question per local civil day, with no repeats in any 365-day window.
    /// A continuous cycle avoids resetting the catalog on New Year's Day or leap day.
    static func question(for date: Date, timeZone: TimeZone = .current) -> String {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let components = local.dateComponents([.year, .month, .day], from: date)

        // Count civil dates in UTC so daylight-saving changes do not shift the schedule.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = utc.date(from: components)!
        let epoch = utc.date(from: DateComponents(year: 2001, month: 1, day: 1))!
        let offset = utc.dateComponents([.day], from: epoch, to: day).day!
        let index = ((offset % schedule.count) + schedule.count) % schedule.count
        return schedule[index]
    }

    /// Fixed SplitMix64 sequence; independent of process hash seeds and app launches.
    private struct ScheduleRandom {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }
}
