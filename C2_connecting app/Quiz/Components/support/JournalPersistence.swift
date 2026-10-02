import Foundation
import SwiftData

struct JournalDaySnapshot {
    var savedAnswer: String?
    var savedQuestion: String?
    var draftAnswer: String?
    var draftQuestion: String?
    var updatedAt: Date?
}

enum JournalPersistenceError: LocalizedError {
    case futureDate
    case emptyAnswer

    var errorDescription: String? {
        switch self {
        case .futureDate: "아직 오지 않은 날에는 기록할 수 없어요."
        case .emptyAnswer: "기억하고 싶은 이야기를 한 줄 남겨주세요."
        }
    }
}

/// Each operation uses a short-lived context. A failed journal save cannot roll back
/// unrelated interest or conversation changes in the app's shared main context.
@MainActor
enum JournalPersistence {
    static func load(date: Date, in context: ModelContext) throws -> JournalDaySnapshot {
        let transaction = makeContext(context)
        let entry = try entry(for: date, in: transaction)
        let draft = try drafts(for: date, in: transaction).first
        return JournalDaySnapshot(
            savedAnswer: entry?.answer,
            savedQuestion: entry?.question,
            draftAnswer: draft?.answer,
            draftQuestion: draft?.question,
            updatedAt: entry?.updatedAt
        )
    }

    static func saveDraft(answer: String, question: String, date: Date, in context: ModelContext) throws {
        guard !QuizDateHelper.isFuture(date) else { throw JournalPersistenceError.futureDate }
        let transaction = makeContext(context)
        let savedEntry = try entry(for: date, in: transaction)
        let existingDrafts = try drafts(for: date, in: transaction)
        let hasNoNewWriting = savedEntry == nil && answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if answer == savedEntry?.answer || hasNoNewWriting {
            existingDrafts.forEach { transaction.delete($0) }
        } else if let draft = existingDrafts.first {
            draft.answer = answer
            draft.updatedAt = Date()
        } else {
            transaction.insert(JournalDraft(date: date, question: question, answer: answer))
        }

        if transaction.hasChanges { try transaction.save() }
    }

    static func saveRecord(answer: String, question: String, date: Date, in context: ModelContext) throws {
        guard !QuizDateHelper.isFuture(date) else { throw JournalPersistenceError.futureDate }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw JournalPersistenceError.emptyAnswer }
        let transaction = makeContext(context)

        if let savedEntry = try entry(for: date, in: transaction) {
            savedEntry.answer = trimmed
            savedEntry.updatedAt = Date()
            // An old record keeps its original question even if the question catalog changes.
        } else {
            transaction.insert(QuizEntry(date: QuizDateHelper.startOfDay(date), question: question, answer: trimmed))
        }
        try drafts(for: date, in: transaction).forEach { transaction.delete($0) }
        try transaction.save()
    }

    static func discardDraft(date: Date, in context: ModelContext) throws {
        let transaction = makeContext(context)
        try drafts(for: date, in: transaction).forEach { transaction.delete($0) }
        if transaction.hasChanges { try transaction.save() }
    }

    static func deleteRecord(date: Date, in context: ModelContext) throws {
        let transaction = makeContext(context)
        if let savedEntry = try entry(for: date, in: transaction) {
            transaction.delete(savedEntry)
        }
        try drafts(for: date, in: transaction).forEach { transaction.delete($0) }
        try transaction.save()
    }

    private static func makeContext(_ source: ModelContext) -> ModelContext {
        let transaction = ModelContext(source.container)
        transaction.autosaveEnabled = false
        return transaction
    }

    private static func entry(for date: Date, in context: ModelContext) throws -> QuizEntry? {
        let start = QuizDateHelper.startOfDay(date)
        let end = QuizDateHelper.calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        var descriptor = FetchDescriptor<QuizEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\QuizEntry.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func drafts(for date: Date, in context: ModelContext) throws -> [JournalDraft] {
        let start = QuizDateHelper.startOfDay(date)
        let end = QuizDateHelper.calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return try context.fetch(FetchDescriptor<JournalDraft>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\JournalDraft.updatedAt, order: .reverse)]
        ))
    }
}
