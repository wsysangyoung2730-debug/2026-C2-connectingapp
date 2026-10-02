//
//  OnboardingIntroPage.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI

struct OnboardingIntroPage: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 32) {
            Text(step.icon)
                .font(.system(size: 80))

            VStack(spacing: 16) {
                Text(step.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.darkBrown)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)

                Text(step.description)
                    .font(.system(size: 16))
                    .foregroundColor(.textGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
            }
        }
    }
}
