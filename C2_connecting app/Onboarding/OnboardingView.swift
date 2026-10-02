//
//  Untitled.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @State private var currentStep: Int = 0
    @State private var termsAgreed: Bool = false

    private let steps = OnboardingStep.mockSteps

    private var currentStepData: OnboardingStep {
        steps[currentStep]
    }

    private var isTermsStep: Bool {
        currentStepData.type == .terms
    }

    private var introStepCount: Int {
        steps.filter { $0.type == .intro }.count
    }

    private var currentIntroIndex: Int {
        min(currentStep, introStepCount - 1)
    }

    private var canProceed: Bool {
        !isTermsStep || termsAgreed
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer()

                contentSection

                Spacer()

                bottomSection
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - UI Sections
private extension OnboardingView {
    var topBar: some View {
        HStack {
            Spacer()

            if !isTermsStep {
                Button("건너뛰기") {
                    handleSkip()
                }
                .font(.system(size: 15))
                .foregroundColor(.textGray)
            }
        }
    }

    var contentSection: some View {
        VStack(spacing: 48) {
            Group {
                if isTermsStep {
                    OnboardingTermsPage(termsAgreed: $termsAgreed)
                } else {
                    OnboardingIntroPage(step: currentStepData)
                }
            }
            .id(currentStep)
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 20)),
                    removal: .opacity.combined(with: .offset(y: -20))
                )
            )

            if !isTermsStep {
                OnboardingProgressView(
                    currentIndex: currentIntroIndex,
                    totalIntroCount: introStepCount
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    var bottomSection: some View {
        OnboardingBottomButton(
            title: currentStep == steps.count - 1 ? "시작하기" : "다음",
            isEnabled: canProceed,
            action: handleNext
        )
    }
}

// MARK: - Actions
private extension OnboardingView {
    func handleNext() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep < steps.count - 1 {
                currentStep += 1
            } else {
                hasCompletedOnboarding = true
            }
        }
    }

    func handleSkip() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = steps.count - 1
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
