//
//  QuizDateHelper.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import Foundation

enum QuizDateHelper {
    static let calendar = Calendar.current

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
