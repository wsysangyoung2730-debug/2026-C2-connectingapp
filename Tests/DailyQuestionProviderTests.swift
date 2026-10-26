import Foundation
import Testing
@testable import C2_connecting_app

@Suite("365일 질문")
@MainActor
struct DailyQuestionProviderTests {
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    private func calendar(_ zone: TimeZone) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = zone
        return result
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, zone: TimeZone? = nil) -> Date {
        calendar(zone ?? seoul).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("365개 질문은 서로 다르고 빈 문장이나 긴 문장이 없다")
    func completeCatalog() {
        let questions = DailyQuestionCatalog.questions
        #expect(questions.count == 365)
        #expect(Set(questions).count == 365)
        #expect(questions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 60 && $0.hasSuffix("?") })
    }

    @Test("연말과 윤년을 가로지르는 어느 365일에도 질문이 반복되지 않는다")
    func fullYearWithoutRepeats() {
        let starts = [date(1999, 12, 1), date(2026, 10, 24), date(2027, 12, 31), date(2028, 1, 1), date(2028, 2, 29)]
        for start in starts {
            let questions = (0..<365).map { offset in
                let day = calendar(seoul).date(byAdding: .day, value: offset, to: start)!
                return DailyQuestionProvider.question(for: day, timeZone: seoul)
            }
            #expect(Set(questions) == Set(DailyQuestionCatalog.questions))
        }
    }

    @Test("같은 날은 시간과 반복 호출에 관계없이 같은 질문을 보여준다")
    func sameCivilDayIsStable() {
        let expected = DailyQuestionProvider.question(for: date(2026, 10, 24), timeZone: seoul)
        for hour in 0..<24 {
            #expect(DailyQuestionProvider.question(for: date(2026, 10, 24, hour: hour), timeZone: seoul) == expected)
        }
    }

    @Test("윤일도 하나의 질문을 사용하고 365일 후에만 순환한다")
    func leapDayAndCycle() {
        let start = date(2028, 2, 28)
        let questions = (0...365).map {
            DailyQuestionProvider.question(for: calendar(seoul).date(byAdding: .day, value: $0, to: start)!, timeZone: seoul)
        }
        #expect(Set(questions.prefix(3)).count == 3)
        #expect(questions[0] == questions[365])
        #expect(Set(questions.prefix(365)).count == 365)
    }

    @Test("시차와 일광절약시간이 있어도 현지의 같은 날짜는 같은 질문이다")
    func localDatesAcrossTimeZones() {
        for zoneName in ["Asia/Seoul", "America/Los_Angeles", "Europe/Berlin", "Pacific/Apia"] {
            let zone = TimeZone(identifier: zoneName)!
            for (month, day) in [(3, 8), (3, 9), (11, 1), (11, 2)] {
                let expected = DailyQuestionProvider.question(for: date(2026, month, day), timeZone: seoul)
                #expect(DailyQuestionProvider.question(for: date(2026, month, day, zone: zone), timeZone: zone) == expected)
            }
            let start = date(2028, 1, 1, zone: zone)
            let questions = (0..<365).map {
                DailyQuestionProvider.question(for: calendar(zone).date(byAdding: .day, value: $0, to: start)!, timeZone: zone)
            }
            #expect(Set(questions).count == 365)
        }
    }

    @Test("현지 자정에만 질문이 바뀐다")
    func midnightBoundary() {
        let midnight = date(2026, 10, 25, hour: 0)
        let before = DailyQuestionProvider.question(for: midnight.addingTimeInterval(-1), timeZone: seoul)
        let after = DailyQuestionProvider.question(for: midnight, timeZone: seoul)
        #expect(before != after)
        #expect(after == DailyQuestionProvider.question(for: midnight.addingTimeInterval(1), timeZone: seoul))
    }

    @Test("새해에 첫 질문으로 초기화되지 않고 이전 날짜도 안정적으로 조회된다")
    func stableAcrossYearBoundary() {
        let yearEnd = DailyQuestionProvider.question(for: date(2026, 12, 31), timeZone: seoul)
        let newYear = DailyQuestionProvider.question(for: date(2027, 1, 1), timeZone: seoul)
        #expect(yearEnd != newYear)
        #expect(DailyQuestionProvider.question(for: date(1999, 12, 31), timeZone: seoul) == DailyQuestionProvider.question(for: date(2000, 12, 30), timeZone: seoul))
    }
}
