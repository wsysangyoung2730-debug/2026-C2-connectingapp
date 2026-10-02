import SwiftUI

enum InterestSheetState: CaseIterable {
    case collapsed
    case mid
    case expanded

    var accessibilityDescription: String {
        switch self {
        case .collapsed: "접힘"
        case .mid: "반쯤 펼침"
        case .expanded: "완전히 펼침"
        }
    }
}

enum InterestLayoutHelper {
    static func height(for state: InterestSheetState, screenHeight: CGFloat) -> CGFloat {
        let availableHeight = max(0, screenHeight - 8)
        switch state {
        case .collapsed: return min(240, availableHeight)
        case .mid: return min(400, availableHeight)
        case .expanded: return availableHeight
        }
    }

    static func nearestState(for currentHeight: CGFloat, screenHeight: CGFloat) -> InterestSheetState {
        InterestSheetState.allCases.min {
            abs(height(for: $0, screenHeight: screenHeight) - currentHeight)
                < abs(height(for: $1, screenHeight: screenHeight) - currentHeight)
        } ?? .collapsed
    }
}
