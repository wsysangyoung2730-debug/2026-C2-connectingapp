//
//  NavigationBar.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/22/26.
//

import SwiftUI

enum MainTab {
    case home
    case friends
}
struct BottomNavigationBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.85, green: 0.8, blue: 0.72))
                .frame(maxWidth: .infinity)
                .frame(height: 1)

            HStack(spacing: 10.74) {
                tabButton(
                    title: "홈",
                    image: Image("home"),
                    tab: .home
                )

                tabButton(
                    title: "추천 친구",
                    image: Image("person"),
                    tab: .friends
                )
            }
            .padding(.horizontal, 74.98)
            .padding(.vertical, 10.74)
            .frame(maxWidth: .infinity, minHeight: 71.61, maxHeight: 71.61)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func tabButton(title: String, image: Image, tab: MainTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3.58) {
                image
                    .renderingMode(.template) // 에셋도 틴트 적용하려면 템플릿 렌더링
                    .font(.system(size: 22, weight: .regular))

                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(
                isSelected
                ? .white
                : Color.textGray
            )
            .padding(.horizontal, 21.5)
            .padding(.vertical, 7.16)
            .frame(width: 117, height: 50, alignment: .top)
            .background(
                isSelected
                ? Color.primaryBrown
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
#Preview {
    BottomNavigationBar(selectedTab: .constant(.home))
        .background(Color(red: 0.96, green: 0.95, blue: 0.92))
}
