import SwiftUI
import SwiftData

struct DiscoveryView: View {
    @Query private var selections: [InterestSelection]
    @ObservedObject private var store = SocialStore.shared
    @State private var selectedInterest = "추천"
    @State private var searchText = ""
    @State private var searchPresented = false

    private var interests: [String] {
        InterestTagCatalog.selection(from: selections.max(by: { $0.updatedAt < $1.updatedAt })?.tags ?? [])
    }
    private var people: [SamplePerson] {
        SamplePerson.all.filter { person in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return store.conversation(for: person.id)?.isBlocked != true
                && (selectedInterest == "추천" || person.interests.map(SamplePerson.normalized).contains(SamplePerson.normalized(selectedInterest)))
                && (query.isEmpty || ([person.name, person.storyTitle] + person.interests).contains { $0.localizedCaseInsensitiveContains(query) })
        }.sorted {
            let lhs = $0.sharedInterests(with: interests).count, rhs = $1.sharedInterests(with: interests).count
            return lhs == rhs ? $0.name < $1.name : lhs > rhs
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("발견").font(.title.weight(.bold))
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("discover.title")
                    Spacer()
                    Button {
                        searchPresented.toggle()
                        if !searchPresented { searchText = "" }
                    } label: {
                        Image(systemName: searchPresented ? "xmark" : "magnifyingglass")
                            .frame(width: 44, height: 44)
                            .background(Color.naldamPaper, in: Circle())
                    }.accessibilityLabel(searchPresented ? "검색 닫기" : "발견 검색")
                }
                Text("좋아하는 것에서 시작되는 새로운 사이.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                if searchPresented { NaldamSearchField(text: $searchText, prompt: "이름, 관심사, 이야기 검색") }
                SocialStorageWarning(message: store.storageError)
                if interests.isEmpty {
                    Label("홈의 봉투에 관심사를 담으면 닮은 친구를 먼저 볼 수 있어요.", systemImage: "envelope.open")
                        .font(.caption).foregroundStyle(Color.naldamSecondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(["추천"] + interests, id: \.self) { interest in
                            Button { selectedInterest = interest } label: {
                                Text(interest == "추천" ? interest : "#\(interest)")
                                    .font(.subheadline).padding(.horizontal, 16).frame(minHeight: 42)
                                    .foregroundStyle(selectedInterest == interest ? Color.naldamPaper : Color.naldamSecondary)
                                    .background(selectedInterest == interest ? Color.naldamAccent : Color.naldamPaper, in: Capsule())
                                    .overlay(Capsule().stroke(selectedInterest == interest ? Color.clear : Color.naldamLine, lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedInterest == interest ? .isSelected : [])
                        }
                    }
                }
                if let first = people.first {
                    featuredPerson(first)
                    if people.count > 1 {
                        Text("이런 이야기도 만나보세요").font(.subheadline.weight(.semibold)).padding(.top, 3)
                        LazyVStack(spacing: 0) {
                            ForEach(Array(people.dropFirst())) { person in
                                NavigationLink { SampleStoryView(person: person) } label: {
                                    HStack(spacing: 12) {
                                        NaldamPersonPortrait(person: person, size: 45)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(person.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.naldamInk)
                                            Text(person.interests.map { "#\($0)" }.joined(separator: " · "))
                                                .font(.caption).foregroundStyle(Color.naldamSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer(minLength: 3)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.naldamSecondary)
                                    }.padding(.vertical, 13)
                                }.buttonStyle(.plain)
                                if person.id != people.last?.id { Divider().overlay(Color.naldamLine) }
                            }
                        }
                    }
                } else {
                    NaldamEmptyState(symbol: "sparkle.magnifyingglass", title: "아직 닿는 이야기가 없어요", message: "다른 관심사나 이름으로 찾아보세요.")
                    Button("전체 이야기 보기") { selectedInterest = "추천"; searchText = "" }
                        .buttonStyle(NaldamPrimaryButtonStyle())
                }
                Label("샘플 프로필과 대화 · 이 기기에서 체험해요", systemImage: "flask")
                    .font(.caption).foregroundStyle(Color.naldamSecondary)
            }
            .foregroundStyle(Color.naldamInk)
            .padding(.horizontal, 22).padding(.top, 5).padding(.bottom, 105)
            .frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            InterestEnvelopePocket().frame(height: 38).background(Color.appBackground)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .background { NaldamEnvelopeBackground() }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("발견").navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: interests) { _, values in
            if !values.contains(selectedInterest) { selectedInterest = "추천" }
        }
    }

    private func featuredPerson(_ person: SamplePerson) -> some View {
        let shared = person.sharedInterests(with: interests)
        return VStack(spacing: 16) {
            HStack {
                Label(shared.isEmpty ? "새롭게 만나는 이야기" : "나와 닮은 관심사", systemImage: "sparkles").foregroundStyle(Color.naldamAccent)
                Spacer()
                Text("오늘의 발견").foregroundStyle(Color.naldamSecondary)
            }.font(.caption)
            NavigationLink { SampleStoryView(person: person) } label: {
                HStack(spacing: 16) {
                    NaldamPersonPortrait(person: person, size: 73)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(person.name).font(.title2.weight(.semibold)).foregroundStyle(Color.naldamInk)
                        Text(shared.isEmpty ? "새로운 취향을 만나보세요" : "함께 좋아하는 것 \(shared.count)개")
                            .font(.caption).foregroundStyle(Color.naldamAccent)
                    }
                }.frame(maxWidth: .infinity)
            }.buttonStyle(.plain)
            Text("“\(person.storyTitle)”").font(.subheadline).foregroundStyle(Color.naldamInk)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            InterestFlowLayout(spacing: 6, centered: true) {
                ForEach(person.interests, id: \.self) { interest in
                    Text("#\(interest)").font(.caption).padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(shared.contains(interest) ? Color.naldamAccent : Color.naldamSecondary)
                        .background(shared.contains(interest) ? Color.naldamSoft : Color.appBackground, in: Capsule())
                }
            }
            NavigationLink { SocialRequestView(person: person) } label: {
                Label("인사 건네기", systemImage: "envelope")
            }
            .buttonStyle(NaldamPrimaryButtonStyle()).accessibilityIdentifier("discover.greet")
        }
        .padding(18)
        .background(Color.naldamPaper, in: UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 26, bottomTrailingRadius: 26, topTrailingRadius: 49))
        .overlay(UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 26, bottomTrailingRadius: 26, topTrailingRadius: 49).stroke(Color.naldamLine, lineWidth: 0.8))
        .shadow(color: Color.naldamInk.opacity(0.04), radius: 12, y: 5)
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
                    Text(person.story).font(.body).lineSpacing(7).foregroundStyle(Color.naldamInk).textSelection(.enabled)
                }.naldamCard()
                Text("내 기록은 자동으로 공개되지 않아요. 이 이야기는 디자인을 확인하기 위한 가상의 예시입니다.")
                    .font(.footnote).foregroundStyle(Color.naldamSecondary)
                NavigationLink { SocialRequestView(person: person) } label: {
                    Label("이 이야기로 대화 시작하기", systemImage: "bubble.left")
                }.buttonStyle(NaldamPrimaryButtonStyle())
            }.padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("공개한 이야기").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).naldamTabBarHidden()
    }
}
