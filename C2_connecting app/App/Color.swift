//
//  Color.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI

extension Color {
    static let appBackground = Color(red: 247 / 255, green: 244 / 255, blue: 238 / 255)
    static let naldamAccent = Color(red: 136 / 255, green: 100 / 255, blue: 72 / 255)
    static let naldamInk = Color(red: 48 / 255, green: 43 / 255, blue: 38 / 255)
    static let naldamSecondary = Color(red: 128 / 255, green: 118 / 255, blue: 108 / 255)
    static let naldamPaper = Color(red: 1, green: 253 / 255, blue: 249 / 255)
    static let naldamLine = Color(red: 232 / 255, green: 224 / 255, blue: 213 / 255)
    static let naldamSoft = Color(red: 238 / 255, green: 230 / 255, blue: 217 / 255)
    static let naldamEnvelope = Color(red: 214 / 255, green: 189 / 255, blue: 160 / 255)
    static let naldamEnvelopeLight = Color(red: 225 / 255, green: 205 / 255, blue: 180 / 255)
    static let naldamGold = Color(red: 239 / 255, green: 187 / 255, blue: 86 / 255)
    static let naldamGoldInk = Color(red: 77 / 255, green: 53 / 255, blue: 24 / 255)
    // Legacy components share the refreshed palette during migration.
    static let primaryBrown = naldamAccent
    static let darkBrown = naldamInk
    static let textGray = naldamSecondary
    static let lightBrown = Color(red: 0.85, green: 0.80, blue: 0.72)      // #d8cbb8
    static let borderBrown = Color(red: 0.91, green: 0.87, blue: 0.81)     // #e8ddcf
    static let cardBackground = Color(red: 1.0, green: 0.99, blue: 0.99)   // #fffdfc
}
