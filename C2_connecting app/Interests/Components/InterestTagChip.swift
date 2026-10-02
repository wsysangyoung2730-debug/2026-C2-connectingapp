//
//  InterestTagChip.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

// 태그 칩

import SwiftUI

struct InterestTagChip: View {
    let title: String
    var isSelected: Bool = false
    var isDashed: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(alignment: .center, spacing: isSelected ? 6 : 10) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(textColor)

                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.62, green: 0.48, blue: 0.31))
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 9)
            .frame(minHeight: 42)
            .background(backgroundShape)
            .overlay { overlayShape }
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if isSelected {
            return Color(red: 0.37, green: 0.27, blue: 0.2)
        }

        if isDashed {
            return Color.primaryBrown.opacity(0.7)
        }

        return Color(red: 0.61, green: 0.59, blue: 0.58)
    }

    private var horizontalPadding: CGFloat {
        if isSelected { return 17 }
        if isDashed { return 20 }
        return 26
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 999)
                .fill(Color(red: 0.91, green: 0.87, blue: 0.81))
        } else if isDashed {
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.clear)
        } else {
            RoundedRectangle(cornerRadius: 999)
                .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
        }
    }

    @ViewBuilder
    private var overlayShape: some View {
        if isDashed {
            RoundedRectangle(cornerRadius: 999)
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                .foregroundColor(Color.primaryBrown.opacity(0.55))
        } else if isSelected {
            RoundedRectangle(cornerRadius: 999)
                .inset(by: 0.5)
                .stroke(Color(red: 0.85, green: 0.8, blue: 0.72), lineWidth: 1)
        }
    }
}

#Preview("기본 태그") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestTagChip(title: "러닝")
            .padding(20)
    }
}

#Preview("선택된 태그") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestTagChip(title: "브랜딩", isSelected: true)
            .padding(20)
    }
}

#Preview("점선 태그") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        InterestTagChip(title: "태그 추가", isDashed: true)
            .padding(20)
    }
}
