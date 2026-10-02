//
//  Color.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI

extension Color {
    static let appBackground = Color(red: 247 / 255, green: 243 / 255, blue: 236 / 255)
    static let naldamAccent = Color(red: 178 / 255, green: 85 / 255, blue: 57 / 255)
    static let naldamInk = Color(red: 61 / 255, green: 48 / 255, blue: 43 / 255)
    static let naldamSecondary = Color(red: 117 / 255, green: 104 / 255, blue: 94 / 255)
    static let naldamPaper = Color(red: 1, green: 253 / 255, blue: 250 / 255)
    static let naldamLine = Color(red: 227 / 255, green: 216 / 255, blue: 204 / 255)
    // Legacy components share the refreshed palette during migration.
    static let primaryBrown = naldamAccent
    static let darkBrown = naldamInk
    static let textGray = naldamSecondary
    static let lightBrown = Color(red: 0.85, green: 0.80, blue: 0.72)      // #d8cbb8
    static let borderBrown = Color(red: 0.91, green: 0.87, blue: 0.81)     // #e8ddcf
    static let cardBackground = Color(red: 1.0, green: 0.99, blue: 0.99)   // #fffdfc
}
