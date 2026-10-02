//
//  InterestTagSlotGrid.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

// 슬롯 그리드

import SwiftUI

struct InterestTagSlotGrid: View {
    let tags: [String]
    let onRemove: (Int) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: -50),
        GridItem(.flexible(), spacing: -50)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(0..<6, id: \.self) { index in
                if index < tags.count {
                    InterestTagChip(
                        title: tags[index],
                        isSelected: true,
                        isDashed: false,
                        action: { onRemove(index) }
                    )
                } else {
                    InterestTagChip(
                        title: "관심사 추가",
                        isSelected: false,
                        isDashed: true,
                        action: nil
                    )
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("빈 슬롯 상태") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestTagSlotGrid(
            tags: [],
            onRemove: { _ in }
        )
        .padding(20)
    }
}

#Preview("일부 태그 상태") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestTagSlotGrid(
            tags: ["러닝", "브랜딩", "스타트업"],
            onRemove: { _ in }
        )
        .padding(20)
    }
}

#Preview("가득 찬 상태") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestTagSlotGrid(
            tags: ["러닝", "브랜딩", "스타트업", "디자인", "개발", "마케팅"],
            onRemove: { _ in }
        )
        .padding(20)
    }
}
