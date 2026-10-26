import Foundation

enum CommunitySafety {
    static let termsVersion = 1
    static let terms = "욕설·괴롭힘·혐오 표현·성적 콘텐츠·폭력과 위협·사칭·광고성 도배를 허용하지 않아요. 신고는 24시간 이내 확인하며, 위반 콘텐츠를 삭제하거나 계정 이용을 제한할 수 있어요."
    nonisolated static let blockedFragments = ["씨발", "시발놈", "개새끼", "병신", "죽여버", "강간", "아동포르노", "fuck", "nigger"]

    /// A first-pass filter, complemented by reports and human moderation.
    nonisolated static func permits(_ text: String) -> Bool {
        let compact = text.precomposedStringWithCompatibilityMapping.lowercased()
            .unicodeScalars.filter { CharacterSet.letters.union(.decimalDigits).contains($0) }
            .map(String.init).joined()
        return !blockedFragments.contains { compact.contains($0) }
    }
}

enum ContentReportReason: String, CaseIterable, Identifiable {
    case harassment, sexual, violence, hate, spam, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .harassment: "욕설·괴롭힘"
        case .sexual: "성적인 콘텐츠"
        case .violence: "폭력·위협"
        case .hate: "혐오·차별"
        case .spam: "광고·사칭·도배"
        case .other: "기타"
        }
    }
}

struct ContentReportTarget: Identifiable {
    let personID: String
    let personName: String
    var roomID: String = ""
    var messageID: String = ""
    var id: String { personID + "_" + roomID + "_" + messageID }
}
