import Foundation
import Testing
@testable import C2_connecting_app

@Suite("실제 채팅의 입력과 계정별 초안")
@MainActor
struct ChatLocalCacheTests {
    private func inDirectory(_ test: (URL) throws -> Void) throws {
        let url = URL.temporaryDirectory.appending(path: "naldam-chat-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        try test(url)
    }

    @Test("두 사용자의 방 주소는 요청 방향에 관계없이 동일하다")
    func canonicalPair() {
        #expect(ChatValidation.roomID("alice", "bob") == ChatValidation.roomID("bob", "alice"))
        #expect(ChatValidation.roomID("alice", "alice") == nil)
        #expect(ChatValidation.roomID("a/b", "bob") == nil)
        #expect(ChatValidation.roomID("a__b", "bob") == nil)
        #expect(ChatValidation.roomID("", "bob") == nil)
    }

    @Test("서버와 같은 메시지 길이 경계를 적용한다")
    func messageBoundaries() {
        #expect(ChatValidation.message(" \n  ") == nil)
        #expect(ChatValidation.message("  안녕하세요\n반가워요  ") == "안녕하세요\n반가워요")
        #expect(ChatValidation.message(String(repeating: "가", count: 2000)) != nil)
        #expect(ChatValidation.message(String(repeating: "가", count: 2001)) == nil)
        #expect(ChatValidation.message(String(repeating: "😀", count: 1000)) != nil)
        #expect(ChatValidation.message(String(repeating: "😀", count: 1001)) == nil)
        #expect(ChatValidation.message(String(repeating: "🏃🏽‍♀️", count: 501)) == nil)
    }

    @Test("로그아웃 후 다른 계정은 이전 초안과 미전송 메시지를 읽지 않는다")
    func accountIsolation() throws {
        try inDirectory { directory in
            let alice = ChatLocalCache(userID: "alice", directory: directory)
            #expect(alice.change {
                $0.drafts["room"] = "나만의 초안"
                $0.outbox.append(.init(id: "stable-id", roomID: "room", body: "첫 인사", createdAt: .now, delivery: .sending))
            })
            let bob = ChatLocalCache(userID: "bob", directory: directory)
            #expect(bob.contents.drafts.isEmpty)
            #expect(bob.contents.outbox.isEmpty)
            #expect(alice.fileURL != bob.fileURL)
            let restored = ChatLocalCache(userID: "alice", directory: directory)
            #expect(restored.contents.drafts["room"] == "나만의 초안")
            #expect(restored.contents.outbox.first?.id == "stable-id")
            #expect(restored.contents.outbox.first?.delivery == .failed)
        }
    }

    @Test("손상된 초안 파일은 덮어쓰지 않는다")
    func preservesCorruptFile() throws {
        try inDirectory { directory in
            let initial = ChatLocalCache(userID: "alice", directory: directory)
            let original = Data("corrupt original".utf8)
            try original.write(to: initial.fileURL)
            let restored = ChatLocalCache(userID: "alice", directory: directory)
            #expect(restored.errorMessage != nil)
            #expect(!restored.change { $0.drafts["room"] = "overwrite" })
            #expect(try Data(contentsOf: initial.fileURL) == original)
        }
    }

    @Test("서버 전달 완료된 항목만 제거하고 다른 초안은 보존한다")
    func acknowledgeOutbox() throws {
        try inDirectory { directory in
            let cache = ChatLocalCache(userID: "alice", directory: directory)
            #expect(cache.change {
                $0.drafts["another-room"] = "다른 초안"
                $0.outbox = [
                    .init(id: "sent", roomID: "room", body: "전송", createdAt: .now, delivery: .sending),
                    .init(id: "retry", roomID: "room", body: "재시도", createdAt: .now, delivery: .failed)
                ]
            })
            #expect(cache.change { $0.outbox.removeAll { $0.id == "sent" } })
            let restored = ChatLocalCache(userID: "alice", directory: directory)
            #expect(restored.contents.outbox.map(\.id) == ["retry"])
            #expect(restored.contents.drafts["another-room"] == "다른 초안")
        }
    }
    @Test("계정 삭제는 그 계정의 초안만 지우며 재시도할 수 있다")
    func erasesOnlyDeletedAccount() throws {
        try inDirectory { directory in
            let alice = ChatLocalCache(userID: "alice", directory: directory)
            let bob = ChatLocalCache(userID: "bob", directory: directory)
            alice.change { $0.drafts["room"] = "삭제할 초안" }
            bob.change { $0.drafts["room"] = "다른 계정 초안" }
            try alice.erase()
            try alice.erase()
            #expect(!FileManager.default.fileExists(atPath: alice.fileURL.path))
            #expect(alice.contents.drafts.isEmpty)
            #expect(ChatLocalCache(userID: "bob", directory: directory).contents.drafts["room"] == "다른 계정 초안")
        }
    }

    @Test("손상된 초안도 명시적인 계정 삭제에서는 제거한다")
    func erasesCorruptCache() throws {
        try inDirectory { directory in
            let first = ChatLocalCache(userID: "alice", directory: directory)
            try Data("invalid".utf8).write(to: first.fileURL)
            let corrupt = ChatLocalCache(userID: "alice", directory: directory)
            #expect(corrupt.errorMessage != nil)
            try corrupt.erase()
            #expect(corrupt.errorMessage == nil)
            #expect(!FileManager.default.fileExists(atPath: first.fileURL.path))
        }
    }

}
