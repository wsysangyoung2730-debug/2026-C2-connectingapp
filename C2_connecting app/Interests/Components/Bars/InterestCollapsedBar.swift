//
//  InterestCollapsedBar.swift.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

// 접힌 상태 바 (메인화면 기본모습)

import SwiftUI

struct InterestCollapsedBar: View {
    let selectedTags: [String]

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.primaryBrown.opacity(0.28))
                .frame(width: 54, height: 6)
                .padding(.top, 10)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("나의 관심사")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primaryBrown)

                    if selectedTags.isEmpty {
                        Text("관심사를 추가하여 더 잘 맞는 친구를 찾아보세요")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    } else {
                        Text(selectedTags.joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(red: 0.94, green: 0.71, blue: 0.27))
                        .frame(width: 49, height: 49)

                    Image(systemName: "chevron.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .offset(y: -5)

                    Image(systemName: "chevron.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .offset(y: 7)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}

#Preview("빈 상태") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestCollapsedBar(selectedTags: [])
            .padding(.horizontal, 20)
    }
}

#Preview("태그 선택 상태") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestCollapsedBar(selectedTags: ["러닝", "브랜딩", "스타트업"])
            .padding(.horizontal, 20)
    }
}
