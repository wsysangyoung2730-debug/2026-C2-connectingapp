import Foundation
import SwiftData
import Testing
@testable import C2_connecting_app

@Suite("기록과 달력")
@MainActor
struct JournalLogicTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        QuizDateHelper.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: QuizEntry.self, JournalDraft.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("달력은 월요일부터 시작하고 빈 셀을 포함한다")
    func mondayFirstCalendar() {
        let cells = QuizDateHelper.monthDates(containing: date(2026, 10, 2))
        #expect(cells.count == 35)
        #expect(cells.prefix(3).allSatisfy { $0 == nil })
        #expect(cells[3] == date(2026, 10, 1))
        let week = QuizDateHelper.weekDates(containing: date(2026, 10, 2))
        #expect(week.count == 7)
        #expect(week.first == date(2026, 9, 28))
        #expect(week.last == date(2026, 10, 4))
    }

    @Test("윤년과 연말 날짜를 정확히 표시한다")
    func calendarBoundaries() {
        #expect(QuizDateHelper.monthDates(containing: date(2024, 2, 1)).compactMap { $0 }.count == 29)
        #expect(QuizDateHelper.monthDates(containing: date(2025, 2, 1)).compactMap { $0 }.count == 28)
        let week = QuizDateHelper.weekDates(containing: date(2026, 1, 1))
        #expect(week.first == date(2025, 12, 29))
        #expect(week.last == date(2026, 1, 4))
    }

    @Test("임시 작성은 별도로 유지되고 기록 저장 시에만 기록이 된다")
    func draftAndSaveLifecycle() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let day = date(2025, 4, 20)
        try JournalPersistence.saveDraft(answer: "산책을 했다", question: "오늘 좋았던 일은?", date: day, in: context)
        let draftSnapshot = try JournalPersistence.load(date: day, in: context)
        #expect(draftSnapshot.savedAnswer == nil)
        #expect(draftSnapshot.draftAnswer == "산책을 했다")

        try JournalPersistence.saveRecord(answer: "  산책을 했다  ", question: "오늘 좋았던 일은?", date: day, in: context)
        let savedSnapshot = try JournalPersistence.load(date: day, in: context)
        #expect(savedSnapshot.savedAnswer == "산책을 했다")
        #expect(savedSnapshot.draftAnswer == nil)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<QuizEntry>()) == 1)
    }

    @Test("수정 중에는 원본이 유지되고 저장해도 원래 질문을 바꾸지 않는다")
    func editingPreservesOriginal() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let day = date(2025, 4, 20)
        try JournalPersistence.saveRecord(answer: "원래 기록", question: "처음 질문", date: day, in: context)
        try JournalPersistence.saveDraft(answer: "수정 중", question: "바뀐 질문", date: day, in: context)
        let editing = try JournalPersistence.load(date: day, in: context)
        #expect(editing.savedAnswer == "원래 기록")
        #expect(editing.draftAnswer == "수정 중")
        try JournalPersistence.saveRecord(answer: "수정한 기록", question: "바뀐 질문", date: day, in: context)
        let saved = try JournalPersistence.load(date: day, in: context)
        #expect(saved.savedQuestion == "처음 질문")
        #expect(saved.savedAnswer == "수정한 기록")
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<QuizEntry>()) == 1)
    }

    @Test("빈 답변과 미래 날짜는 저장하지 않는다")
    func rejectsInvalidRecords() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        #expect(throws: JournalPersistenceError.self) {
            try JournalPersistence.saveRecord(answer: "  \n", question: "질문", date: date(2025, 4, 20), in: context)
        }
        let tomorrow = QuizDateHelper.calendar.date(byAdding: .day, value: 1, to: Date())!
        #expect(throws: JournalPersistenceError.self) {
            try JournalPersistence.saveRecord(answer: "미래", question: "질문", date: tomorrow, in: context)
        }
    }

    @Test("임시 작성 취소와 기록 삭제는 다른 날짜의 기록에 영향을 주지 않는다")
    func discardAndDeleteAreScoped() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let first = date(2025, 4, 20)
        let second = date(2025, 4, 21)
        try JournalPersistence.saveRecord(answer: "첫날", question: "질문", date: first, in: context)
        try JournalPersistence.saveRecord(answer: "다음 날", question: "질문", date: second, in: context)
        try JournalPersistence.saveDraft(answer: "수정 중", question: "질문", date: first, in: context)
        try JournalPersistence.discardDraft(date: first, in: context)
        #expect(try JournalPersistence.load(date: first, in: context).savedAnswer == "첫날")
        #expect(try JournalPersistence.load(date: first, in: context).draftAnswer == nil)
        try JournalPersistence.deleteRecord(date: first, in: context)
        #expect(try JournalPersistence.load(date: first, in: context).savedAnswer == nil)
        #expect(try JournalPersistence.load(date: second, in: context).savedAnswer == "다음 날")
    }

    @Test("공유 컨텍스트의 미저장 변경을 건드리지 않는다")
    func leavesUnrelatedPendingChangesIntact() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        context.autosaveEnabled = false
        let pending = QuizEntry(date: date(2025, 4, 10), question: "다른 질문", answer: "아직 저장하지 않은 내용")
        context.insert(pending)
        try JournalPersistence.saveRecord(answer: "오늘 기록", question: "질문", date: date(2025, 4, 20), in: context)
        #expect(context.hasChanges)
        #expect(pending.answer == "아직 저장하지 않은 내용")
        #expect(try ModelContext(context.container).fetchCount(FetchDescriptor<QuizEntry>()) == 1)
    }

    @Test("메인 컨텍스트에서도 저장한 기록을 다시 조회할 수 있다")
    func mainContextFetchesCommittedRecord() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let day = date(2025, 4, 20)
        try JournalPersistence.saveRecord(answer: "첫 기록", question: "질문", date: day, in: context)
        let firstFetch = try context.fetch(FetchDescriptor<QuizEntry>())
        #expect(firstFetch.count == 1)
        #expect(firstFetch.first?.answer == "첫 기록")
        try JournalPersistence.saveRecord(answer: "바꾼 기록", question: "질문", date: day, in: context)
        context.processPendingChanges()
        let refreshed = try context.fetch(FetchDescriptor<QuizEntry>())
        #expect(refreshed.first?.answer == "바꾼 기록")
    }

    @Test("같은 날짜의 다른 시간에 여러 번 저장해도 기록과 임시 작성은 하나씩만 유지된다")
    func repeatedWritesDoNotDuplicateTheDay() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let day = date(2025, 4, 20)
        for hour in [8, 13, 20] {
            let timestamp = QuizDateHelper.calendar.date(byAdding: .hour, value: hour, to: day)!
            try JournalPersistence.saveDraft(answer: "\(hour)시 작성", question: "질문", date: timestamp, in: context)
        }
        #expect(try ModelContext(context.container).fetchCount(FetchDescriptor<JournalDraft>()) == 1)
        for hour in [8, 13, 20] {
            let timestamp = QuizDateHelper.calendar.date(byAdding: .hour, value: hour, to: day)!
            try JournalPersistence.saveRecord(answer: "\(hour)시 기록", question: "질문", date: timestamp, in: context)
        }
        let freshContext = ModelContext(context.container)
        #expect(try freshContext.fetchCount(FetchDescriptor<QuizEntry>()) == 1)
        #expect(try freshContext.fetchCount(FetchDescriptor<JournalDraft>()) == 0)
        #expect(try JournalPersistence.load(date: day, in: context).savedAnswer == "20시 기록")
    }

    @Test("기존 디스크 저장소에 임시 작성 모델을 추가해도 기록과 관심사를 보존한다")
    func diskStoreMigrationAndDraftRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NaldamMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("migration-test.store")
        let day = date(2025, 4, 20)
        let nextDay = date(2025, 4, 21)
        let createdAt = day.addingTimeInterval(3600)
        let tags = ["#독서", "산책", "음악"]

        // Scope and drain each container before opening the next schema, as an app upgrade would.
        try autoreleasepool {
            let originalSchema = Schema([QuizEntry.self, InterestSelection.self])
            let configuration = ModelConfiguration(schema: originalSchema, url: storeURL, cloudKitDatabase: .none)
            let original = try ModelContainer(for: originalSchema, configurations: [configuration])
            defer { withExtendedLifetime(original) {} }
            original.mainContext.autosaveEnabled = false
            original.mainContext.insert(QuizEntry(
                date: day, question: "C2 때의 질문", answer: "지켜야 할 나의 기록",
                createdAt: createdAt, updatedAt: createdAt
            ))
            original.mainContext.insert(InterestSelection(tags: tags, updatedAt: createdAt))
            try original.mainContext.save()
        }
        #expect(FileManager.default.fileExists(atPath: storeURL.path))

        try autoreleasepool {
            let upgradedSchema = Schema([QuizEntry.self, InterestSelection.self, JournalDraft.self])
            let configuration = ModelConfiguration(schema: upgradedSchema, url: storeURL, cloudKitDatabase: .none)
            let upgraded = try ModelContainer(for: upgradedSchema, configurations: [configuration])
            defer { withExtendedLifetime(upgraded) {} }
            let entries = try upgraded.mainContext.fetch(FetchDescriptor<QuizEntry>())
            let selections = try upgraded.mainContext.fetch(FetchDescriptor<InterestSelection>())
            #expect(entries.count == 1)
            #expect(entries.first?.question == "C2 때의 질문")
            #expect(entries.first?.answer == "지켜야 할 나의 기록")
            #expect(entries.first?.createdAt == createdAt)
            #expect(selections.count == 1)
            #expect(selections.first?.tags == tags)
            try JournalPersistence.saveDraft(answer: "아직 쓰고 있는 이야기", question: "다음 날의 질문", date: nextDay, in: upgraded.mainContext)
        }

        try autoreleasepool {
            let schema = Schema([QuizEntry.self, InterestSelection.self, JournalDraft.self])
            let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let reopened = try ModelContainer(for: schema, configurations: [configuration])
            defer { withExtendedLifetime(reopened) {} }
            let oldRecord = try JournalPersistence.load(date: day, in: reopened.mainContext)
            let recoveredDraft = try JournalPersistence.load(date: nextDay, in: reopened.mainContext)
            #expect(oldRecord.savedAnswer == "지켜야 할 나의 기록")
            #expect(oldRecord.savedQuestion == "C2 때의 질문")
            #expect(recoveredDraft.draftAnswer == "아직 쓰고 있는 이야기")
            #expect(recoveredDraft.draftQuestion == "다음 날의 질문")
            #expect(recoveredDraft.savedAnswer == nil)
            #expect(try reopened.mainContext.fetchCount(FetchDescriptor<QuizEntry>()) == 1)
            #expect(try reopened.mainContext.fetch(FetchDescriptor<InterestSelection>()).first?.tags == tags)
        }
    }
}
