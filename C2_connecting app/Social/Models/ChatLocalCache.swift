import Foundation
import CryptoKit

struct ChatOutboxItem: Codable, Equatable, Identifiable {
    let id: String
    let roomID: String
    let body: String
    let createdAt: Date
    var delivery: ChatMessage.Delivery
}

/// Only drafts and unsent messages live on disk. Each account owns a separate protected file.
@MainActor
final class ChatLocalCache {
    struct Contents: Codable {
        var version = 1
        var drafts: [String: String] = [:]
        var outbox: [ChatOutboxItem] = []
    }
    private(set) var contents = Contents()
    private(set) var errorMessage: String?
    private var writable = true
    let fileURL: URL

    init(userID: String, directory: URL = URL.applicationSupportDirectory.appending(path: "Naldam/Chat")) {
        let key = SHA256.hash(data: Data(userID.utf8)).map { String(format: "%02x", $0) }.joined()
        fileURL = directory.appending(path: "\(key).json")
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                contents = try JSONDecoder().decode(Contents.self, from: Data(contentsOf: fileURL))
                guard contents.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                // A previous process cannot confirm an in-flight write. Retry uses the same ID.
                contents.outbox = contents.outbox.map { item in
                    var item = item; item.delivery = .failed; return item
                }
            }
        } catch {
            contents = Contents()
            writable = false
            errorMessage = "보관한 초안을 읽지 못했어요. 원본은 유지했으며, 다시 실행해 확인해 주세요."
        }
    }

    func erase() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
        contents = Contents(); writable = true; errorMessage = nil
    }

    @discardableResult
    func change(_ edit: (inout Contents) -> Void) -> Bool {
        guard writable else { return false }
        var next = contents
        edit(&next)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            contents = next
            errorMessage = nil
            return true
        } catch {
            errorMessage = "초안을 기기에 보관하지 못했어요. 저장 공간을 확인해 주세요."
            return false
        }
    }
}
