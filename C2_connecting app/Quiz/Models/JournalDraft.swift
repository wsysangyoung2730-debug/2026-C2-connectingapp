import Foundation
import SwiftData

/// Drafts are separate from finished records so unfinished writing never changes a saved entry.
@Model
final class JournalDraft {
    var date: Date = Date()
    var question: String = ""
    var answer: String = ""
    var updatedAt: Date = Date()

    init(date: Date, question: String, answer: String, updatedAt: Date = Date()) {
        self.date = QuizDateHelper.startOfDay(date)
        self.question = question
        self.answer = answer
        self.updatedAt = updatedAt
    }
}
