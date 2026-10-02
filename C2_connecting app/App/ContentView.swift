//
//  ContentView.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI

struct ContentView: View {
    // 온보딩 완료 여부를 영속화하여 앱 재실행 시에도 유지
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                // 온보딩이 끝난 경우: 메인 화면 진입
                MainHomeView()
                    .transition(.opacity)
            } else {
                // 온보딩 진행 화면
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
}
