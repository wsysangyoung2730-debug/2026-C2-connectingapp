//
//  C2_connecting_appApp.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI
import SwiftData

@main
struct C2_connecting_appApp: App {
    var body: some Scene {
        WindowGroup {
            MainHomeView()
        }
        .modelContainer(for: [
            QuizEntry.self,
            InterestSelection.self
        ])
    }
}
