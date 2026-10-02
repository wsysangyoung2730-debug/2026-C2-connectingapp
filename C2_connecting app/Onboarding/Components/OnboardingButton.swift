//
//  OnboardingButton.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI

struct OnboardingBottomButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? Color.primaryBrown : Color.lightBrown)
                .cornerRadius(15)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
        .disabled(!isEnabled)
    }
}
