//
//  QuizEntry.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import Foundation
import SwiftData

@Model
final class QuizEntry {
    var date: Date
    var question: String
    var answer: String
    var createdAt: Date
    var updatedAt: Date

    init(
        date: Date,
        question: String,
        answer: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.date = date
        self.question = question
        self.answer = answer 
        self.createdAt = createdAt //저장 시각
        self.updatedAt = updatedAt //마지막 수정 시각
    }
}
