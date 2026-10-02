//
//  InterestRecommendationSection.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

// 추천 태그 섹션

import SwiftUI

struct InterestRecommendationSection: View {
    let tags: [String]
    let selectedTags: [String]
    let onSelect: (String) -> Void


    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("추천 태그")
                .font(Font.custom("SF Pro", size: 13))
                .foregroundColor(Color(red: 0.43, green: 0.42, blue: 0.4))
                .frame(maxWidth: .infinity, alignment: .topLeading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self) { tag in
                        let isSelected = selectedTags.contains(tag)

                        InterestTagChip(
                            title: tag,
                            isSelected: isSelected,
                            isDashed: false,
                            action: {
                                guard !isSelected else { return }
                                onSelect(tag)
                            }
                        )
                        .opacity(isSelected ? 0.45 : 1.0)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}

#Preview("기본 상태") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestRecommendationSection(
            tags: ["러닝", "브랜딩", "스타트업", "디자인", "개발", "마케팅"],
            selectedTags: [],
            onSelect: { _ in }
        )
        .padding(20)
    }
}

#Preview("일부 선택 상태") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestRecommendationSection(
            tags: ["러닝", "브랜딩", "스타트업", "디자인", "개발", "마케팅"],
            selectedTags: ["러닝", "디자인"],
            onSelect: { _ in }
        )
        .padding(20)
    }
}
