//
//  InterestEditorView.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

import SwiftUI

private struct InterestTopCurveShape: Shape {
    var curveHeight: CGFloat = 110

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let safeCurveHeight = min(max(curveHeight, 0), rect.height * 0.45)

        path.move(to: CGPoint(x: 0, y: safeCurveHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: safeCurveHeight),
            control: CGPoint(x: rect.width / 2, y: -safeCurveHeight)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

struct InterestEditorView: View {
    @Binding var workingTags: [String]
    @Binding var searchText: String

    let onSave: () -> Void

    @State private var showLimitMessage = false

    private var filteredTags: [String] {
        InterestTagCatalog.filteredTags(query: searchText)
    }

    private var countTextColor: Color {
        workingTags.count == 6 ? .green : .gray
    }

    private var countFont: Font {
        workingTags.count == 6
        ? .system(size: 14, weight: .bold)
        : .system(size: 14, weight: .medium)
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.94, green: 0.71, blue: 0.27))
                        .frame(width: 49, height: 49)

                    Image(systemName: "down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .offset(y: -5)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .offset(y: 7)
                }
                .offset(y: -58)
                .padding(.bottom, -52)

                Text("아래로 내려 접기")
                    .font(
                        Font.custom("SF Pro Text", size: 12)
                            .weight(.medium)
                    )
                    .foregroundColor(Color(red: 0.78, green: 0.75, blue: 0.72))
                    .padding(.top, -3)
            }

            Text("나의 관심사 편집")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primaryBrown)
                .padding(.top, -6)

            InterestTagSlotGrid(tags: workingTags) { index in
                workingTags.remove(at: index)
            }
            .padding(.top,20)
            
            InterestSearchBar(query: $searchText)
            .padding(.top,20)


            InterestRecommendationSection(
                tags: filteredTags,
                selectedTags: workingTags
            ) { tag in
                guard workingTags.count < 6 else {
                    showLimitMessage = true
                    return
                }
                guard !workingTags.contains(tag) else { return }
                workingTags.append(tag)
            }
            .padding(.top,20)

            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Text("\(workingTags.count)/6개의 관심사를 설정했어요")
                    .font(countFont)
                    .foregroundColor(countTextColor)
            }

            Button(action: onSave) {
                Text("저장하기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(red: 0.94, green: 0.71, blue: 0.27))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.top, 6)

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 34)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            InterestTopCurveShape(curveHeight: 120)
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
        )
        .clipShape(InterestTopCurveShape(curveHeight: 120))
        .overlay(
            InterestTopCurveShape(curveHeight: 120)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: -4)
        .alert("관심사는 최대 6개까지만 선택할 수 있습니다.", isPresented: $showLimitMessage) {
            Button("확인", role: .cancel) { }
        }
    }
}

// MARK: - Previews

#Preview("빈 상태") {
    struct PreviewWrapper: View {
        @State private var workingTags: [String] = []
        @State private var searchText: String = ""

        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                InterestEditorView(
                    workingTags: $workingTags,
                    searchText: $searchText,
                    onSave: {}
                )
                .padding(.top, 20)
            }
        }
    }

    return PreviewWrapper()
}

#Preview("태그 선택 상태") {
    struct PreviewWrapper: View {
        @State private var workingTags: [String] = ["러닝", "브랜딩", "스타트업"]
        @State private var searchText: String = ""

        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                InterestEditorView(
                    workingTags: $workingTags,
                    searchText: $searchText,
                    onSave: {}
                )
                .padding(.top, 20)
            }
        }
    }

    return PreviewWrapper()
}
