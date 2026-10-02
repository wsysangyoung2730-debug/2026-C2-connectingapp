//
//  DailyQuestionProvider.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import Foundation

enum DailyQuestionProvider {
    static func question(for date: Date) -> String { //날짜에 따른 질문 추출
        let questions = [
            "오늘 가장 오래 기억에 남을 순간은 무엇이었나요?",
            "오늘 나를 가장 많이 웃게 만든 일은 무엇이었나요?",
            "오늘의 나를 가장 잘 설명하는 감정은 무엇인가요?",
            "오늘 다른 사람과 나누고 싶은 경험은 무엇인가요?",
            "오늘 내가 조금 성장했다고 느낀 순간은 언제였나요?",
            "오늘 가장 고마웠던 일은 무엇이었나요?",
            "오늘 다시 떠올리고 싶은 장면은 무엇인가요?"
        ]

        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return questions[day % questions.count]
    }
}
