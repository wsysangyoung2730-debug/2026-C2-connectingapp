import Foundation

struct ChatProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let interests: [String]

    nonisolated static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").lowercased()
    }

    func sharedInterests(with tags: [String]) -> [String] {
        let selected = Set(tags.map(Self.normalized))
        return interests.filter { selected.contains(Self.normalized($0)) }
    }
}

enum ChatRoomStatus: String { case pending, active, declined }

struct ChatRoom: Identifiable, Equatable {
    let id: String
    var person: ChatProfile
    var status: ChatRoomStatus
    let isIncoming: Bool
    var isArchived = false
    var isBlocked = false
    var updatedAt: Date
    var lastMessage: String?
    var hasUnread = false
}

struct ChatMessage: Identifiable, Equatable {
    enum Delivery: String, Codable { case sending, sent, failed }
    let id: String
    let body: String
    let createdAt: Date
    let isMine: Bool
    var delivery: Delivery
    var error: String?
}

enum ChatValidation {
    static func message(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Match the UTF-16 string-size boundary verified against the Firestore emulator.
        guard !value.isEmpty, value.utf16.count <= 2_000 else { return nil }
        return value
    }

    static func roomID(_ first: String, _ second: String) -> String? {
        guard first != second, !first.isEmpty, !second.isEmpty,
              !first.contains("/"), !second.contains("/"),
              !first.contains("__"), !second.contains("__"), first.count <= 128, second.count <= 128 else { return nil }
        return [first, second].sorted().joined(separator: "__")
    }

    static func interests(_ tags: [String]) -> [String] {
        InterestTagCatalog.selection(from: tags)
    }
}
