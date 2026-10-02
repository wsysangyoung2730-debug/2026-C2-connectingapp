//
//  MainHomeView.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import SwiftUI

struct MainHomeView: View {
    @State private var selectedTab: MainTab = .home
    @State private var isPresentingTodayQuiz = false
    @State private var isInterestSheetDimmed = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 25) {
                            TodayPromptCard {
                                isPresentingTodayQuiz = true
                            }

                            WeeklyRecordCard()

                            // 관심사 섹션은 다음 단계에서 붙일 자리
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color.white.opacity(0.6))
                                .frame(height: 260)
                                .overlay(
                                    Text("2028년 업데이트 예정")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.gray)
                                )
                                .padding(.top, 8)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 220)
                    }
                }

                Color.black
                    .opacity(isInterestSheetDimmed ? 0.22 : 0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.2), value: isInterestSheetDimmed)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    InterestBottomSheet(isBackgroundDimmed: $isInterestSheetDimmed)
                        .frame(height: 650)

                    BottomNavigationBar(selectedTab: $selectedTab)
                }
            }
            .navigationDestination(isPresented: $isPresentingTodayQuiz) {
                QuizPageView()
            }
        }
    }
}

#Preview {
    MainHomeView()
}
