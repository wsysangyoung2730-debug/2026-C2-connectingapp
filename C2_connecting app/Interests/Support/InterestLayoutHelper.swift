//
//  InterestLayoutHelper.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

import SwiftUI

enum InterestSheetState: CaseIterable {
    case collapsed
    case mid
    case expanded
}

enum InterestLayoutHelper {
    static func height(for state: InterestSheetState, screenHeight: CGFloat) -> CGFloat {
        switch state {
        case .collapsed:
            return 132
        case .mid:
            return 280
        case .expanded:
            return screenHeight - 20
        }
    }

    static func nearestState(for currentHeight: CGFloat, screenHeight: CGFloat) -> InterestSheetState {
        let states: [InterestSheetState] = [.collapsed, .mid, .expanded]

        return states.min {
            abs(height(for: $0, screenHeight: screenHeight) - currentHeight)
            <
            abs(height(for: $1, screenHeight: screenHeight) - currentHeight)
        } ?? .collapsed
    }
}
