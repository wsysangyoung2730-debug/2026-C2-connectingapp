//
//  InterestEnvelopeStage.swift.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

// 중간 상태 봉투 UI

import SwiftUI

struct InterestEnvelopeStage: View {
    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.primaryBrown.opacity(0.28))
                .frame(width: 54, height: 6)
                .padding(.top, 10)

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .frame(width: 220, height: 130)
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 110, y: 65))
                    path.addLine(to: CGPoint(x: 220, y: 0))
                }
                .stroke(Color.primaryBrown.opacity(0.25), lineWidth: 2)
                .frame(width: 220, height: 65)

                Text("나의 관심사 편집")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryBrown)
                    .offset(y: -87)
            }

            Text("위로 더 올리면 관심사를 편집할 수 있어요")
                .font(.system(size: 14))
                .foregroundColor(.gray)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Envelope Stage") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestEnvelopeStage()
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
    }
}
