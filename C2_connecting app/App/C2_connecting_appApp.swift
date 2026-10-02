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
            ContentView()
                .tint(.naldamAccent)
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "ko_KR"))
        }
        .modelContainer(for: [
            QuizEntry.self,
            JournalDraft.self,
            InterestSelection.self
        ], inMemory: NaldamRuntime.isUITesting)
    }
}

enum NaldamRuntime {
    static var isUITesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-naldam-ui-testing")
        #else
        false
        #endif
    }
}
