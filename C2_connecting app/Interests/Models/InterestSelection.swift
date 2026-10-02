//
//  InterestSelection.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

import Foundation
import SwiftData

@Model
final class InterestSelection {
    var id: UUID
    var tags: [String]
    var updatedAt: Date

    init(tags: [String] = [], updatedAt: Date = Date()) {
        self.id = UUID()
        self.tags = Array(tags.prefix(6))
        self.updatedAt = updatedAt
    }
}
