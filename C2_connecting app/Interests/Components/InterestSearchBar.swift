//
//  InterestSearchBar.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

// 검색바

import SwiftUI

struct InterestSearchBar: View {
    @Binding var query: String

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image("search")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.43, green: 0.42, blue: 0.4))
                .frame(width: 20, height: 20)
                .offset(x: -18)

            TextField("관심사 검색하기", text: $query)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.43, green: 0.42, blue: 0.4))
                .tint(.primaryBrown)
        }
        .padding(.leading, 48)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54, alignment: .leading)
        .background(Color(red: 0.97, green: 0.95, blue: 0.93))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.5)
                .stroke(Color(red: 0.85, green: 0.8, blue: 0.72), lineWidth: 1)
        )
    }
}

#Preview("기본 상태") {
    struct PreviewWrapper: View {
        @State private var query: String = ""

        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                InterestSearchBar(query: $query)
                    .frame(width: 314)
                    .padding(20)
            }
        }
    }

    return PreviewWrapper()
}

#Preview("입력 상태") {
    struct PreviewWrapper: View {
        @State private var query: String = "러닝"

        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                InterestSearchBar(query: $query)
                    .frame(width: 314)
                    .padding(20)
            }
        }
    }

    return PreviewWrapper()
}
