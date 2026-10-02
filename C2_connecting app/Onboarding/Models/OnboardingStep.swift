//
//  OnboardingStep.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI

struct OnboardingStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let type: StepType

    enum StepType {
        case intro
        case terms
    }
}

extension OnboardingStep {
    static let mockSteps: [OnboardingStep] = [
        OnboardingStep(
            title: "매일의 순간을 기록하세요",
            description: "하루의 경험을 작성하고\n다른 러너들과 공유해보세요",
            icon: "✍️",
            type: .intro
        ),
        OnboardingStep(
            title: "관심사로 연결되세요",
            description: "같은 관심사를 가진 사람들과\n이야기를 나눌 수 있어요",
            icon: "🤝",
            type: .intro
        ),
        OnboardingStep(
            title: "매일 새로운 질문",
            description: "오늘의 질문에 답하며\n나를 돌아보는 시간을 가져보세요",
            icon: "💭",
            type: .intro
        ),
        OnboardingStep(
            title: "서비스 이용약관",
            description: "",
            icon: "",
            type: .terms
        )
    ]
}
