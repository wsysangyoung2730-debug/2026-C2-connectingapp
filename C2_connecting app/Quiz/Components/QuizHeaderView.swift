//
//  QuizHeaderView.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import SwiftUI

struct QuizHeaderView: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                // Left custom back control
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("뒤로")
                    }
                    .foregroundColor(Color.primaryBrown)
                    .frame(width: 60, alignment: .leading)
                }

                Spacer()

                // Center title
                Text(title)
                    .font(Font.custom("Inter_18pt-SemiBold", size: 18))
                    .foregroundColor(.darkBrown)

                Spacer()

                // Right placeholder to balance layout (same width as back control)
                Color.clear
                    .frame(width: 60, height: 1)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 59, maxHeight: 59, alignment: .center)

            // Divider under the header
            Rectangle()
                .fill(Color.primaryBrown.opacity(0.15))
                .frame(height: 1)
        }
        .background(Color.appBackground)
    }
}
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        QuizHeaderView(title: "오늘의 경험", onBack: { print("뒤로가기") })
    }
}
