//
//  InterestBottomSheet.swift.swift
//  C2_connecting app
//
//  Created by woo sangyoung on 4/23/26.
//

// 전체 바텀 시트

import SwiftUI
import SwiftData

struct InterestBottomSheet: View {
    @Binding var isBackgroundDimmed: Bool

    @Environment(\.modelContext) private var modelContext
    @Query private var selections: [InterestSelection]

    @State private var sheetState: InterestSheetState = .collapsed
    @State private var dragOffset: CGFloat = 0

    @State private var workingTags: [String] = []
    @State private var searchText: String = ""

    @State private var showSavedAlert = false

    private var savedSelection: InterestSelection? {
        selections.first
    }

    private var savedTags: [String] {
        savedSelection?.tags ?? []
    }

    var body: some View {
        GeometryReader { proxy in
            let screenHeight = proxy.size.height
            let baseHeight = InterestLayoutHelper.height(for: sheetState, screenHeight: screenHeight)
            let currentHeight = max(
                InterestLayoutHelper.height(for: .collapsed, screenHeight: screenHeight),
                min(
                    InterestLayoutHelper.height(for: .expanded, screenHeight: screenHeight),
                    baseHeight - dragOffset
                )
            )

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.appBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.primaryBrown.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: -2)

                content(for: currentHeight, screenHeight: screenHeight)
            }
            .frame(height: currentHeight, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let predictedHeight = baseHeight - value.predictedEndTranslation.height
                        let next = InterestLayoutHelper.nearestState(
                            for: predictedHeight,
                            screenHeight: screenHeight
                        )

                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            sheetState = next
                            dragOffset = 0
                            isBackgroundDimmed = next != .collapsed
                        }
                    }
            )
            .alert("저장되었습니다.", isPresented: $showSavedAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("관심사 설정이 반영되었습니다")
            }
            .onAppear {
                workingTags = savedTags
                isBackgroundDimmed = sheetState != .collapsed
            }
            .onChange(of: sheetState) { _, newValue in
                isBackgroundDimmed = newValue != .collapsed
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func content(for currentHeight: CGFloat, screenHeight: CGFloat) -> some View {
        let collapsedHeight = InterestLayoutHelper.height(for: .collapsed, screenHeight: screenHeight)
        let midHeight = InterestLayoutHelper.height(for: .mid, screenHeight: screenHeight)

        if currentHeight < (collapsedHeight + midHeight) / 2 {
            InterestCollapsedBar(selectedTags: savedTags)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        sheetState = .mid
                        isBackgroundDimmed = true
                    }
                }
        } else if currentHeight < (midHeight + screenHeight) / 2 {
            InterestEnvelopeStage()
        } else {
            InterestEditorView(
                workingTags: $workingTags,
                searchText: $searchText,
                onSave: saveTags
            )
        }
    }

    private func saveTags() {
        if let savedSelection {
            savedSelection.tags = Array(workingTags.prefix(6))
            savedSelection.updatedAt = Date()
        } else {
            let newSelection = InterestSelection(tags: Array(workingTags.prefix(6)))
            modelContext.insert(newSelection)
        }

        searchText = ""
        showSavedAlert = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            sheetState = .collapsed
            isBackgroundDimmed = false
        }
    }
}

#Preview("Interest Bottom Sheet") {
    struct PreviewWrapper: View {
        @State private var isBackgroundDimmed = false

        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Color.black
                    .opacity(isBackgroundDimmed ? 0.22 : 0)
                    .ignoresSafeArea()

                InterestBottomSheet(isBackgroundDimmed: $isBackgroundDimmed)
            }
        }
    }

    return PreviewWrapper()
        .modelContainer(for: [InterestSelection.self], inMemory: true)
}
