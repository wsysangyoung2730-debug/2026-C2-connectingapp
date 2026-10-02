//
//  QuizDateHelper.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import Foundation

enum QuizDateHelper {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func isFuture(_ date: Date) -> Bool {
        let startOfSelected = calendar.startOfDay(for: date)
        let startOfToday = calendar.startOfDay(for: Date())
        return startOfSelected > startOfToday
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func weekDates(containing date: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
    }

    /// Monday-first cells, including unique leading/trailing blank positions in a caller's grid.
    static func monthDates(containing date: Date) -> [Date?] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month.start)
        let leadingCount = (firstWeekday + 5) % 7
        var result: [Date?] = Array(repeating: nil, count: leadingCount)
        result += days.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month.start) }.map(Optional.some)
        let trailingCount = (7 - result.count % 7) % 7
        result += Array(repeating: nil, count: trailingCount)
        return result
    }

    static func yearMonthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }

    static func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월"
        return formatter.string(from: date)
    }

    static func fullDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }

    static func weekdaySymbol(for date: Date) -> String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let index = calendar.component(.weekday, from: date) - 1
        return symbols[index]
    }
}
