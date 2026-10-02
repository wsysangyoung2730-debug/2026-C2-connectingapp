//
//  OnboardingProgressView.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI

struct OnboardingProgressView: View {
    let currentIndex: Int
    let totalIntroCount: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalIntroCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.primaryBrown : Color.lightBrown)
                    .frame(width: index == currentIndex ? 32 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: currentIndex)
            }
        }
    }
}
