import SwiftUI
import SwiftData

/// One piece of paper moves out of a fixed envelope. Only its visible content receives touches.
struct InterestBottomSheet: View {
    @Binding var isBackgroundDimmed: Bool
    @Binding var isExpanded: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \InterestSelection.updatedAt, order: .reverse) private var selections: [InterestSelection]
    @AppStorage("profileName") private var profileName = "나"
    @FocusState private var searchIsFocused: Bool

    @State private var sheetState: InterestSheetState = .collapsed
    @State private var dragOffset: CGFloat = 0
    @State private var workingTags: [String] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var limitReached = false

    init(isBackgroundDimmed: Binding<Bool>, isExpanded: Binding<Bool> = .constant(false)) {
        _isBackgroundDimmed = isBackgroundDimmed
        _isExpanded = isExpanded
    }

    private var savedSelection: InterestSelection? { selections.first }
    private var savedTags: [String] { savedSelection?.tags ?? [] }
    private var visibleTags: [String] { sheetState == .expanded ? workingTags : savedTags }
    private var animation: Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.4, dampingFraction: 0.86)
    }

    var body: some View {
        GeometryReader { geometry in
            let height = InterestLayoutHelper.height(for: sheetState, screenHeight: geometry.size.height)
            let minimum = InterestLayoutHelper.height(for: .collapsed, screenHeight: geometry.size.height)
            let maximum = InterestLayoutHelper.height(for: .expanded, screenHeight: geometry.size.height)
            let visibleHeight = min(maximum, max(minimum, height - dragOffset))

            ZStack(alignment: .bottom) {
                envelopePaper(height: visibleHeight)
                    .overlay(alignment: .top) {
                        pullHandle(baseHeight: height, availableHeight: geometry.size.height)
                    }
                    .frame(height: visibleHeight)

                InterestEnvelopePocket()
                    .frame(height: sheetState == .expanded ? 38 : 66)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .alert("관심사를 저장하지 못했어요", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "잠시 후 다시 시도해 주세요.")
        }
        .onAppear { workingTags = Array(savedTags.prefix(6)) }
        .onChange(of: savedTags) { _, tags in
            if sheetState != .expanded { workingTags = Array(tags.prefix(6)) }
        }
        .onChange(of: isBackgroundDimmed) { _, dimmed in
            // The parent dismisses this custom sheet by changing the backdrop binding.
            if !dimmed && sheetState != .collapsed { move(to: .collapsed) }
        }
        .onDisappear {
            searchIsFocused = false
            sheetState = .collapsed
            dragOffset = 0
            isBackgroundDimmed = false
            isExpanded = false
        }
    }

    private func envelopePaper(height: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if sheetState == .expanded {
                    HStack {
                        Button("취소") { move(to: .collapsed) }
                            .foregroundStyle(Color.naldamSecondary)
                        Spacer()
                        Button("저장", action: saveTags)
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("interests.save")
                    }
                    .font(.body)
                    .tint(.naldamAccent)
                    .frame(minHeight: 44)
                    .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    NaldamAvatar(name: profileName, size: 44)
                    Text("나의 관심사")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.naldamInk)
                }
                .accessibilityElement(children: .combine)

                selectedTags

                if sheetState == .mid {
                    Text("좋아하는 것에서 이야기가 시작돼요.\n나를 닮은 관심사를 담아보세요.")
                        .font(.subheadline)
                        .foregroundStyle(Color.naldamSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Button {
                        move(to: .expanded)
                    } label: {
                        Label("관심사 편집", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NaldamPrimaryButtonStyle())
                    .accessibilityIdentifier("interests.edit")
                }

                if sheetState == .expanded { editingContent }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)
            .padding(.top, 70)
            .padding(.bottom, sheetState == .expanded ? 58 : 82)
        }
        .scrollDisabled(sheetState == .collapsed)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .frame(height: height)
        .background {
            InterestPaperShape()
                .fill(Color.naldamPaper)
                .shadow(color: Color.naldamInk.opacity(0.09), radius: 16, x: 0, y: -5)
        }
        .clipShape(InterestPaperShape())
        .contentShape(InterestPaperShape())
        .overlay {
            InterestPaperShape().stroke(Color.naldamLine.opacity(0.7), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var selectedTags: some View {
        if visibleTags.isEmpty {
            Button {
                move(to: .expanded)
            } label: {
                Label("관심사를 담아보세요", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(Color.naldamAccent)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Color.naldamAccent.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("interests.add")
        } else {
            InterestFlowLayout(spacing: 8, centered: true) {
                ForEach(Array(displayedTags.enumerated()), id: \.offset) { _, tag in
                    PaperInterestChip(title: tag, selected: sheetState == .expanded) {
                        if sheetState == .expanded {
                            workingTags.removeAll { $0 == tag }
                            limitReached = false
                        } else {
                            move(to: .mid)
                        }
                    }
                    .accessibilityLabel(sheetState == .expanded ? "\(tag) 삭제" : "\(tag), 관심사 펼치기")
                }
                if sheetState == .collapsed && visibleTags.count > 3 {
                    Text("+\(visibleTags.count - 3)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.naldamSecondary)
                        .frame(minHeight: 40)
                }
            }
        }
    }

    private var displayedTags: [String] {
        sheetState == .collapsed ? Array(visibleTags.prefix(3)) : visibleTags
    }

    private var editingContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("어떤 이야기를 좋아하나요?")
                    .font(.headline)
                Spacer(minLength: 4)
                Text("\(workingTags.count) / 6")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.naldamSecondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.naldamSecondary)
                TextField("관심사 검색", text: $searchText)
                    .focused($searchIsFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { searchIsFocused = false }
                    .accessibilityIdentifier("interests.search")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.naldamSecondary)
                            .frame(width: 32, height: 44)
                    }
                    .accessibilityLabel("검색어 지우기")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 15))

            Text(searchText.isEmpty ? "이런 관심사는 어때요?" : "검색 결과")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.naldamSecondary)

            if InterestTagCatalog.filteredTags(query: searchText).isEmpty {
                Text("일치하는 관심사가 없어요.\n다른 단어로 검색해 주세요.")
                    .font(.subheadline)
                    .foregroundStyle(Color.naldamSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                InterestFlowLayout(spacing: 8) {
                    ForEach(InterestTagCatalog.filteredTags(query: searchText), id: \.self) { tag in
                        let selected = workingTags.contains(tag)
                        PaperInterestChip(title: tag, selected: selected, selectionMark: true) {
                            toggle(tag)
                        }
                        .accessibilityLabel("\(tag), \(selected ? "선택됨, 선택 해제" : "선택하기")")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            if limitReached {
                Label("관심사는 최대 6개까지 담을 수 있어요.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.naldamAccent)
                    .accessibilityIdentifier("interests.limit")
            }

            Text("최대 6개까지 선택할 수 있어요. 관심사는 발견 화면의 추천에 사용돼요. 나의 기록은 공개되지 않아요.")
                .font(.footnote)
                .foregroundStyle(Color.naldamSecondary)
                .lineSpacing(4)

            Button("관심사 저장", action: saveTags)
                .buttonStyle(NaldamPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Color.naldamInk)
        .padding(.top, 6)
    }

    private func pullHandle(baseHeight: CGFloat, availableHeight: CGFloat) -> some View {
        VStack(spacing: 3) {
            Button {
                let next: InterestSheetState = sheetState == .collapsed ? .mid : (sheetState == .mid ? .expanded : .collapsed)
                move(to: next)
            } label: {
                Image(systemName: sheetState == .expanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.naldamAccent.gradient, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sheetState == .expanded ? "관심사 닫기" : "관심사 펼치기")
            .accessibilityValue(sheetState.accessibilityDescription)
            .accessibilityHint("위아래로 조절하거나 두 번 탭해 크기를 바꿀 수 있어요.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: move(to: sheetState == .collapsed ? .mid : .expanded)
                case .decrement: move(to: sheetState == .expanded ? .mid : .collapsed)
                @unknown default: break
                }
            }
            .accessibilityIdentifier("interests.handle")

            Text(sheetState == .expanded ? "아래로 내려 접기" : "위로 당겨 펼치기")
                .font(.caption2)
                .foregroundStyle(Color.naldamSecondary)
                .accessibilityHidden(true)
        }
        .frame(width: 160, height: 68)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    searchIsFocused = false
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    let next = InterestLayoutHelper.nearestState(
                        for: baseHeight - value.predictedEndTranslation.height,
                        screenHeight: availableHeight
                    )
                    move(to: next)
                }
        )
    }

    private func toggle(_ tag: String) {
        if workingTags.contains(tag) {
            workingTags.removeAll { $0 == tag }
            limitReached = false
        } else if workingTags.count < 6 {
            workingTags.append(tag)
            limitReached = false
        } else {
            limitReached = true
        }
    }

    private func move(to state: InterestSheetState) {
        searchIsFocused = false
        if sheetState == .collapsed || state != .expanded {
            workingTags = Array(savedTags.prefix(6))
            searchText = ""
            limitReached = false
        }
        withAnimation(animation) {
            sheetState = state
            dragOffset = 0
            isBackgroundDimmed = state != .collapsed
            isExpanded = state == .expanded
        }
    }

    private func saveTags() {
        let tags = Array(workingTags.prefix(6))
        if let selection = savedSelection {
            let originalTags = selection.tags
            let originalDate = selection.updatedAt
            selection.tags = tags
            selection.updatedAt = Date()
            do {
                try modelContext.save()
                move(to: .collapsed)
            } catch {
                selection.tags = originalTags
                selection.updatedAt = originalDate
                errorMessage = "변경 내용이 저장되지 않았어요. 선택한 관심사는 그대로 두었으니 다시 저장해 주세요."
            }
        } else {
            let selection = InterestSelection(tags: tags)
            modelContext.insert(selection)
            do {
                try modelContext.save()
                move(to: .collapsed)
            } catch {
                modelContext.delete(selection)
                errorMessage = "변경 내용이 저장되지 않았어요. 선택한 관심사는 그대로 두었으니 다시 저장해 주세요."
            }
        }
    }
}

#Preview {
    InterestBottomSheet(isBackgroundDimmed: .constant(false))
        .background(Color.appBackground)
        .modelContainer(for: InterestSelection.self, inMemory: true)
}
