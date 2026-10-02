import Foundation

/// Public, fictional content used only to preview discovery before a server is connected.
struct SamplePerson: Identifiable, Hashable {
    let id: String
    let name: String
    let interests: [String]
    let storyTitle: String
    let story: String
    let greeting: String

    func sharedInterests(with interests: [String]) -> [String] {
        let selected = Set(interests.map(Self.normalized))
        return self.interests.filter { selected.contains(Self.normalized($0)) }
    }

    nonisolated static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "").lowercased()
    }

    static let all: [SamplePerson] = [
        .init(id: "seoyeon", name: "서연", interests: ["독서", "산책", "기록"],
              storyTitle: "동네 서점에서 뜻밖의 문장을 만났어요.",
              story: "산책하다 우연히 작은 서점에 들렀어요. 책장을 넘기다 지금의 저에게 꼭 필요한 문장을 만났습니다.\n\n아무것도 하지 않은 것 같은 하루에도 나를 위한 시간은 남는다는 말이었어요. 집에 돌아와 그 문장을 노트에 적어 두었습니다.",
              greeting: "안녕하세요! 좋아하는 책이나 산책 이야기를 나눠 보고 싶어요."),
        .init(id: "doyun", name: "도윤", interests: ["음악", "산책", "사진"],
              storyTitle: "좋아하는 노래 한 곡으로 하루가 달라졌어요.",
              story: "조금 지친 퇴근길이었는데 오랜만에 좋아하던 노래가 흘러나왔어요. 발걸음에 맞춰 듣다 보니 집으로 가는 길이 짧게 느껴졌습니다.\n\n내일은 한 정거장 먼저 내려서 새로운 음악과 함께 걸어 보려고요.",
              greeting: "안녕하세요! 요즘 자주 듣는 노래가 있으신가요?"),
        .init(id: "minseo", name: "민서", interests: ["독서", "영화", "커피"],
              storyTitle: "책 한 권과 커피 한 잔이면 충분한 오후.",
              story: "오늘은 해야 할 일 목록을 잠시 접어 두고 카페 창가에 앉았어요. 빨리 읽으려 하지 않고 마음에 드는 문장을 몇 번씩 다시 읽었습니다.\n\n이런 여유를 일주일에 한 번쯤은 선물하고 싶어요.",
              greeting: "독서 이야기를 나누고 싶어요. 최근에 마음에 남은 책이 있나요?"),
        .init(id: "jiwoo", name: "지우", interests: ["산책", "러닝", "건강"],
              storyTitle: "늘 걷던 길에서 새로운 풍경을 찾았어요.",
              story: "매일 지나던 길인데 오늘은 나무 사이로 들어오는 햇빛이 눈에 띄었어요. 잠깐 멈춰 숨을 고르니 마음까지 가벼워졌습니다.\n\n좋은 산책길을 발견하면 누군가에게 알려 주고 싶어져요.",
              greeting: "산책 코스가 궁금해요. 자주 걷는 길에 대해 이야기해 주세요.")
    ]

    static func person(id: String) -> SamplePerson? { all.first { $0.id == id } }
}

enum LocalConversationStatus: String, Codable {
    case outgoingRequest, incomingRequest, active, declined
}

struct LocalMessage: Identifiable, Codable, Equatable {
    enum Origin: String, Codable { case me, sample }
    let id: UUID
    let body: String
    let createdAt: Date
    let origin: Origin
}

struct LocalConversation: Identifiable, Codable, Equatable {
    let id: UUID
    let personID: String
    var status: LocalConversationStatus
    var messages: [LocalMessage] = []
    var draft = ""
    var isArchived = false
    var isBlocked = false
    var updatedAt: Date = Date()
    var lastReadAt: Date?

    var person: SamplePerson? { SamplePerson.person(id: personID) }
    var unreadCount: Int {
        messages.filter { $0.origin == .sample && $0.createdAt > (lastReadAt ?? .distantPast) }.count
    }
}

struct LocalSocialData: Codable {
    var version = 1
    var conversations: [LocalConversation] = []
}
