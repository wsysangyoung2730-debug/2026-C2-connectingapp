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
    init() {
        FirebaseBootstrap.configureIfAvailable()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .defaultAppStorage(NaldamRuntime.preferences)
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
    #if DEBUG
    // Never compiled into a Release build; no Firebase account or network is used.
    static var isStoreScreenshot: Bool {
        isUITesting && ProcessInfo.processInfo.arguments.contains("-naldam-store-screenshot")
    }
    static var screenshotScreen: String? {
        guard isStoreScreenshot else { return nil }
        return ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-naldam-screen=") })?
            .replacingOccurrences(of: "-naldam-screen=", with: "")
    }
    #endif
    @MainActor static func seedPreviewIfRequested(in context: ModelContext) {
        #if DEBUG
        guard isUITesting, ProcessInfo.processInfo.arguments.contains("-naldam-seeded-ui"),
              (try? context.fetchCount(FetchDescriptor<QuizEntry>())) == 0 else { return }
        for offset in 1...8 {
            guard let date = QuizDateHelper.calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let answers = ["잠깐의 산책이 하루를 바꿔줬다.", "천천히 달려도, 끝까지 달린 나.", "오랜 친구의 안부가 반가웠다.", "별일 없는 하루도, 꽤 괜찮았다.", "서두르지 않기로 한 하루."]
            context.insert(QuizEntry(date: date, question: DailyQuestionProvider.question(for: date), answer: answers[(offset - 1) % answers.count]))
        }
        context.insert(InterestSelection(tags: ["러닝", "기록", "산책", "음악", "독서", "사진"]))
        try? context.save()
        #endif
    }

    static let preferences: UserDefaults = {
        #if DEBUG
        if isUITesting {
            let preferences = UserDefaults(suiteName: "naldam-ui-\(UUID().uuidString)")!
            if isStoreScreenshot { preferences.set("하루", forKey: "profileName") }
            preferences.set(!ProcessInfo.processInfo.arguments.contains("-naldam-show-onboarding"),
                            forKey: "hasCompletedOnboarding")
            return preferences
        }
        #endif
        return .standard
    }()

    static var isUITesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-naldam-ui-testing")
        #else
        false
        #endif
    }
}
