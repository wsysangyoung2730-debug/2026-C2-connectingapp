//
//  OnboardingTermsPage.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/21/26.
//

import SwiftUI

struct OnboardingTermsPage: View {
    @Binding var termsAgreed: Bool

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("서비스 이용약관")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.darkBrown)

                Text("서비스 이용을 위해 동의가 필요합니다")
                    .font(.system(size: 14))
                    .foregroundColor(.textGray)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("개인정보 수집 및 이용 안내")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.darkBrown)

                        Text("당신이 기록한 내용은 더 나은 서비스 제공을 위해 사용됩니다.")
                            .font(.system(size: 14))
                            .foregroundColor(.textGray)
                            .lineSpacing(8)
                    }

                    Divider()
                        .overlay(Color.borderBrown)

                    Group {
                        Text("친구 추천 기능")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.darkBrown)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("• 작성하신 기록과 관심사는 비슷한 관심사를 가진 사용자를 추천하는 데 활용됩니다.")
                            Text("• 기록 내용의 키워드와 감정 분석을 통해 맞춤형 추천을 제공합니다.")
                            Text("• 개인을 특정할 수 있는 민감한 정보는 추천 알고리즘에서 제외됩니다.")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.textGray)
                        .lineSpacing(8)
                    }

                    Divider()
                        .overlay(Color.borderBrown)

                    Group {
                        Text("데이터 보안")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.darkBrown)

                        Text("모든 기록은 암호화되어 안전하게 보관되며, 제3자에게 제공되지 않습니다.")
                            .font(.system(size: 14))
                            .foregroundColor(.textGray)
                            .lineSpacing(8)
                    }
                }
                .padding(24)
            }
            .frame(maxHeight: 350)
            .background(Color.cardBackground)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.lightBrown, lineWidth: 1)
            )

            agreementSection
        }
    }

    private var agreementSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                termsAgreed.toggle()
            } label: {
                Image(systemName: termsAgreed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(.primaryBrown)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("(필수) 위 내용을 모두 확인했으며")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primaryBrown)

                Text("기록 내용이 친구 추천 기능 활성화를 위해 사용되는 것에 동의합니다.")
                    .font(.system(size: 15))
                    .foregroundColor(.darkBrown)
                    .lineSpacing(6)
            }

            Spacer()
        }
    }
}
