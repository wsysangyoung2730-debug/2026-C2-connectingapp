import SwiftUI
import SwiftData

struct DiscoveryView: View {
    @Query private var selections: [InterestSelection]
    @ObservedObject private var store = SocialStore.shared
    @State private var selectedInterest = "전체"
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var interests: [String] {
        Array(Set((selections.max(by: { $0.updatedAt < $1.updatedAt })?.tags ?? [])
            .map(SamplePerson.normalized))).sorted()
    }
    private var people: [SamplePerson] {
        SamplePerson.all.filter { person in
            let blocked = store.conversation(for: person.id)?.isBlocked == true
            let matchesTag = selectedInterest == "전체" || person.interests.map(SamplePerson.normalized).contains(selectedInterest)
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty || ([person.name, person.storyTitle] + person.interests)
                .contains { $0.localizedCaseInsensitiveContains(query) }
            return !blocked && matchesTag && matchesSearch
        }.sorted {
            let lhs = $0.sharedInterests(with: interests).count
            let rhs = $1.sharedInterests(with: interests).count
            return lhs == rhs ? $0.name < $1.name : lhs > rhs
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("이야기가 통할지도 몰라요")
                        .font(.title2.weight(.bold)).foregroundStyle(Color.naldamInk)
                    Text("관심사와 공개한 이야기로 알아가요.")
                        .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                }
                SocialSampleBanner()
                SocialStorageWarning(message: store.storageError)
                searchField
                if interests.isEmpty {
                    Label("홈의 봉투에서 관심사를 담으면, 공통 관심사가 많은 순서로 볼 수 있어요.", systemImage: "envelope.open")
                        .font(.footnote).foregroundStyle(Color.naldamSecondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["전체"] + interests, id: \.self) { interest in
                            Button { selectedInterest = interest; searchFocused = false } label: {
                                Text(interest).font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 18).frame(minHeight: 44)
                                    .foregroundStyle(selectedInterest == interest ? Color.white : Color.naldamInk)
                                    .background(selectedInterest == interest ? Color.naldamAccent : Color.naldamLine.opacity(0.65), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedInterest == interest ? .isSelected : [])
                        }
                    }
                }
                if people.isEmpty {
                    NaldamEmptyState(symbol: "sparkle.magnifyingglass", title: "아직 닿는 이야기가 없어요", message: "다른 관심사나 검색어로 찾아보세요. 현재는 샘플 프로필만 제공돼요.")
                    Button("전체 이야기 보기") { selectedInterest = "전체"; searchText = "" }
                        .buttonStyle(NaldamPrimaryButtonStyle())
                } else {
                    ForEach(people) { person in
                        DiscoveryPersonCard(person: person, sharedInterests: person.sharedInterests(with: interests))
                    }
                }
            }
            .padding(20).padding(.bottom, 30)
        }
        .background(Color.appBackground)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("발견")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .onDisappear { searchFocused = false }
        .onChange(of: interests) { _, values in
            if !values.contains(selectedInterest) { selectedInterest = "전체" }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.naldamSecondary)
            TextField("이름, 관심사, 이야기 검색", text: $searchText)
                .font(.subheadline).autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit { searchFocused = false }
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(14).background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct DiscoveryPersonCard: View {
    let person: SamplePerson
    let sharedInterests: [String]
    @ObservedObject private var store = SocialStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SocialPersonHeading(person: person)
            Text(sharedInterests.isEmpty ? "새로운 취향을 알아가 보세요." : "\(sharedInterests.joined(separator: ", ")) 이야기가 통해요.")
                .font(.footnote).foregroundStyle(Color.naldamSecondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("공개한 샘플 이야기").font(.caption.weight(.semibold)).foregroundStyle(Color.naldamAccent)
                Text(person.storyTitle).font(.title3.weight(.semibold)).foregroundStyle(Color.naldamInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(Color.naldamLine).frame(height: 1)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { actions }
                VStack(alignment: .leading, spacing: 12) { actions }
            }
        }
        .naldamCard()
    }

    @ViewBuilder private var actions: some View {
        NavigationLink { SampleStoryView(person: person) } label: {
            Label("이야기 읽기", systemImage: "doc.text")
                .font(.subheadline.weight(.medium)).frame(minHeight: 44)
        }
        Spacer(minLength: 0)
        if let item = store.conversation(for: person.id), item.status == .active && !item.isArchived {
            NavigationLink { ChatDetailView(conversationID: item.id) } label: {
                Label("대화 열기", systemImage: "bubble.left").font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
        } else {
            NavigationLink { SocialRequestView(person: person) } label: {
                Label(store.conversation(for: person.id)?.status == .outgoingRequest ? "요청 확인" : "대화 요청", systemImage: "bubble.left")
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
        }
    }
}

struct SampleStoryView: View {
    let person: SamplePerson
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SocialSampleBanner(compact: true)
                SocialPersonHeading(person: person)
                VStack(alignment: .leading, spacing: 20) {
                    Label("공개한 샘플 이야기", systemImage: "doc.text")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.naldamAccent)
                    Text(person.storyTitle).font(.title.weight(.bold)).foregroundStyle(Color.naldamInk)
                    Text(person.story).font(.body).lineSpacing(7).foregroundStyle(Color.naldamInk)
                        .textSelection(.enabled)
                }
                .naldamCard()
                Text("내 기록은 자동으로 공개되지 않아요. 이 이야기는 디자인을 확인하기 위한 가상의 예시입니다.")
                    .font(.footnote).foregroundStyle(Color.naldamSecondary)
                NavigationLink { SocialRequestView(person: person) } label: {
                    Label("이 이야기로 대화 시작하기", systemImage: "bubble.left")
                }.buttonStyle(NaldamPrimaryButtonStyle())
            }.padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("공개한 이야기").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
