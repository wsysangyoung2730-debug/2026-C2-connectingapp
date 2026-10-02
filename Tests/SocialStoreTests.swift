import Foundation
import Testing
@testable import C2_connecting_app

@Suite("샘플 발견과 로컬 대화")
@MainActor
struct SocialStoreTests {
    /// Each test owns one fresh temporary child directory, never the user's app data.
    private func withStore(_ test: (URL, SocialStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("naldam-social-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("social.json")
        try test(file, SocialStore(fileURL: file))
    }

    @Test("관심사 비교에서 해시와 공백을 정규화한다")
    func normalizedInterestMatching() {
        let person = SamplePerson.all[0]
        #expect(person.sharedInterests(with: ["#독서", " 산책 "]) == ["독서", "산책"])
        #expect(person.sharedInterests(with: ["#독서", "독서"]) == ["독서"])
        #expect(person.sharedInterests(with: ["수영"]).isEmpty)
        #expect(SamplePerson.normalized(" #SWIFT ") == "swift")
    }

    @Test("첫 실행은 빈 목록이며 요청은 중복 생성하지 않는다")
    func requestLifecycleAndDeduplication() throws {
        try withStore { _, store in
            #expect(store.conversations.isEmpty)
            #expect(store.unreadCount == 0)
            let person = SamplePerson.all[0]
            #expect(store.requestConversation(with: person))
            #expect(store.requestConversation(with: person))
            #expect(store.conversations.count == 1)
            let item = try #require(store.conversation(for: person.id))
            #expect(store.outgoingRequests.count == 1)
            #expect(!store.send("수락 전 메시지", id: item.id))
            #expect(item.messages.isEmpty)
            #expect(store.acceptRequest(id: item.id))
            #expect(store.activeConversations.count == 1)
            #expect(store.conversation(id: item.id)?.messages.count == 1)
            #expect(store.acceptRequest(id: item.id))
            #expect(store.conversation(id: item.id)?.messages.count == 1)
        }
    }

    @Test("초안을 복원하며 메시지 저장 후 초안만 비운다")
    func draftsAndMessagesSurviveReload() throws {
        try withStore { file, store in
            let person = SamplePerson.all[0]
            #expect(store.requestConversation(with: person))
            let id = try #require(store.conversation(for: person.id)).id
            #expect(store.acceptRequest(id: id))
            #expect(store.saveDraft("아직 쓰는 중\n다음 문장", id: id))
            let restoredDraft = SocialStore(fileURL: file)
            #expect(restoredDraft.conversation(id: id)?.draft == "아직 쓰는 중\n다음 문장")
            #expect(store.send("  안녕하세요  ", id: id))
            let restoredMessage = SocialStore(fileURL: file)
            #expect(restoredMessage.conversation(id: id)?.messages.last?.body == "안녕하세요")
            #expect(restoredMessage.conversation(id: id)?.messages.last?.origin == .me)
            #expect(restoredMessage.conversation(id: id)?.messages.count == 2)
            #expect(restoredMessage.conversation(id: id)?.draft == "")
        }
    }

    @Test("빈 메시지와 글자 수 초과 메시지는 저장하지 않는다")
    func validatesMessageContent() throws {
        try withStore { _, store in
            let person = SamplePerson.all[0]
            #expect(store.requestConversation(with: person))
            let id = try #require(store.conversation(for: person.id)).id
            #expect(store.acceptRequest(id: id))
            #expect(!store.send(" \n ", id: id))
            #expect(!store.send(String(repeating: "가", count: 2_001), id: id))
            #expect(!store.send("없는 대화", id: UUID()))
            #expect(store.conversation(id: id)?.messages.count == 1)
            #expect(store.send(String(repeating: "가", count: 2_000), id: id))
            #expect(store.conversation(id: id)?.messages.last?.body.count == 2_000)
        }
    }

    @Test("읽음 상태는 유지되며 내가 남긴 메시지는 배지에 포함하지 않는다")
    func unreadStatePersists() throws {
        try withStore { file, store in
            let person = SamplePerson.all[0]
            #expect(store.requestConversation(with: person))
            let id = try #require(store.conversation(for: person.id)).id
            #expect(store.acceptRequest(id: id))
            #expect(store.unreadCount == 1)
            store.markRead(id: id)
            #expect(store.unreadCount == 0)
            #expect(store.send("내 메시지", id: id))
            #expect(store.unreadCount == 0)
            #expect(SocialStore(fileURL: file).unreadCount == 0)
            #expect(store.addSampleRequests())
            #expect(store.unreadCount == 2)
        }
    }

    @Test("나가기와 차단은 메시지와 초안을 삭제하지 않는다")
    func archivingAndBlockingPreserveData() throws {
        try withStore { file, store in
            let person = SamplePerson.all[0]
            #expect(store.requestConversation(with: person))
            let id = try #require(store.conversation(for: person.id)).id
            #expect(store.acceptRequest(id: id))
            #expect(store.send("보존할 메시지", id: id))
            #expect(store.saveDraft("보존할 초안", id: id))
            #expect(store.archive(id: id))
            #expect(store.activeConversations.isEmpty)
            #expect(!store.send("나간 대화", id: id))
            #expect(store.requestConversation(with: person))
            #expect(store.activeConversations.count == 1)
            #expect(store.setBlocked(true, id: id))
            #expect(store.activeConversations.isEmpty)
            #expect(store.blockedConversations.count == 1)
            #expect(!store.send("차단된 대화", id: id))
            #expect(store.setBlocked(false, id: id))
            let restored = SocialStore(fileURL: file)
            #expect(restored.activeConversations.count == 1)
            #expect(restored.conversation(id: id)?.messages.count == 2)
            #expect(restored.conversation(id: id)?.draft == "보존할 초안")
        }
    }

    @Test("받은 샘플 요청은 중복하지 않으며 거절 상태를 복원한다")
    func incomingRequestsAndDecline() throws {
        try withStore { file, store in
            #expect(store.addSampleRequests())
            #expect(store.addSampleRequests())
            #expect(store.incomingRequests.count == 2)
            let item = try #require(store.incomingRequests.first)
            #expect(store.declineRequest(id: item.id))
            #expect(store.incomingRequests.count == 1)
            #expect(store.addSampleRequests())
            #expect(store.incomingRequests.count == 1)
            let restored = SocialStore(fileURL: file)
            #expect(restored.incomingRequests.count == 1)
            #expect(restored.conversation(id: item.id)?.status == .declined)
            #expect(restored.conversation(id: item.id)?.isArchived == true)
        }
    }

    @Test("손상된 저장 파일은 읽기 실패 후에도 원본을 보존한다")
    func corruptFileIsNeverOverwritten() throws {
        try withStore { file, _ in
            let original = Data("not-json".utf8)
            try original.write(to: file)
            let store = SocialStore(fileURL: file)
            #expect(store.storageError != nil)
            #expect(!store.requestConversation(with: SamplePerson.all[0]))
            #expect(!store.addSampleRequests())
            #expect(store.conversations.isEmpty)
            #expect(try Data(contentsOf: file) == original)
        }
    }

    @Test("지원하지 않는 저장 버전도 덮어쓰지 않는다")
    func unsupportedVersionIsPreserved() throws {
        try withStore { file, _ in
            let original = Data("{\"version\":999,\"conversations\":[]}".utf8)
            try original.write(to: file)
            let store = SocialStore(fileURL: file)
            #expect(store.storageError != nil)
            #expect(!store.requestConversation(with: SamplePerson.all[0]))
            #expect(try Data(contentsOf: file) == original)
        }
    }

    @Test("쓰기 실패 시 저장 성공 상태를 보여주지 않는다")
    func failedWriteDoesNotPublishChanges() throws {
        try withStore { file, _ in
            // A regular file cannot be used as the parent directory of a JSON file.
            let original = Data("occupied".utf8)
            try original.write(to: file)
            let unavailableFile = file.appendingPathComponent("unavailable.json")
            let store = SocialStore(fileURL: unavailableFile)
            #expect(!store.requestConversation(with: SamplePerson.all[0]))
            #expect(store.storageError != nil)
            #expect(store.conversations.isEmpty)
            #expect(try Data(contentsOf: file) == original)
        }
    }
}
