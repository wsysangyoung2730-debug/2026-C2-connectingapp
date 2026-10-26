import SwiftUI

struct DiscoveryView: View {
    @ObservedObject private var store = LiveChatStore.shared
    @State private var selectedInterest = "추천"
    @State private var searchText = ""
    @State private var searchPresented = false

    private var interests: [String] {
        store.publishedProfile?.interests ?? []
    }
    private var people: [ChatProfile] {
        store.profiles.filter { person in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return store.room(for: person.id)?.isBlocked != true
                && (selectedInterest == "추천" || person.interests.map(ChatProfile.normalized).contains(ChatProfile.normalized(selectedInterest)))
                && (query.isEmpty || ([person.name, person.interests.map { "#\($0)" }.joined(separator: " · ")] + person.interests).contains { $0.localizedCaseInsensitiveContains(query) })
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
                if searchPresented { NaldamSearchField(text: $searchText, prompt: "이름이나 관심사 검색") }
                SocialStorageWarning(message: store.errorMessage)
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
                if store.isLoading && people.isEmpty {
                    ProgressView("닮은 관심사를 찾고 있어요").frame(maxWidth: .infinity).padding(28)
                } else if let first = people.first {
                    featuredPerson(first)
                    if people.count > 1 {
                        Text("이런 친구도 만나보세요").font(.subheadline.weight(.semibold)).padding(.top, 3)
                        LazyVStack(spacing: 0) {
                            ForEach(Array(people.dropFirst())) { person in
                                NavigationLink { PublicPersonView(person: person) } label: {
                                    HStack(spacing: 12) {
                                        ChatPersonPortrait(person: person, size: 45)
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
                if store.hasMoreProfiles {
                    Button("친구 더 보기") { Task { await store.loadMoreProfiles() } }
                        .frame(maxWidth: .infinity, minHeight: 44).disabled(store.isLoading)
                }
                if store.errorMessage != nil {
                    Button("다시 연결하기") { store.reconnect() }.frame(minHeight: 44)
                }
                Text("공개된 관심사에서 시작해요. 개인 기록은 서로에게 보이지 않아요.")
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

    private func featuredPerson(_ person: ChatProfile) -> some View {
        let shared = person.sharedInterests(with: interests)
        return VStack(spacing: 16) {
            HStack {
                Label(shared.isEmpty ? "새롭게 만나는 친구" : "나와 닮은 관심사", systemImage: "sparkles").foregroundStyle(Color.naldamAccent)
                Spacer()
                Text("오늘의 발견").foregroundStyle(Color.naldamSecondary)
            }.font(.caption)
            NavigationLink { PublicPersonView(person: person) } label: {
                HStack(spacing: 16) {
                    ChatPersonPortrait(person: person, size: 73)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(person.name).font(.title2.weight(.semibold)).foregroundStyle(Color.naldamInk)
                        Text(shared.isEmpty ? "새로운 취향을 만나보세요" : "함께 좋아하는 것 \(shared.count)개")
                            .font(.caption).foregroundStyle(Color.naldamAccent)
                    }
                }.frame(maxWidth: .infinity)
            }.buttonStyle(.plain)
            Text("가벼운 안부로 이야기를 시작해 보세요.").font(.subheadline).foregroundStyle(Color.naldamInk)
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

struct PublicPersonView: View {
    let person: ChatProfile
    @State private var reportTarget: ContentReportTarget?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SocialPersonHeading(person: person)
                VStack(alignment: .leading, spacing: 16) {
                    Label("좋아하는 것에서 시작되는 이야기", systemImage: "leaf")
                        .font(.headline).foregroundStyle(Color.naldamAccent)
                    if person.interests.isEmpty {
                        Text("아직 공개한 관심사가 없어요.").foregroundStyle(Color.naldamSecondary)
                    } else {
                        SocialInterestTags(tags: person.interests)
                    }
                    Text("가벼운 안부와 함께 서로의 취향을 알아가 보세요.")
                        .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                }.naldamCard()
                Text("개인 기록과 사진은 자동으로 공개되지 않아요.")
                    .font(.footnote).foregroundStyle(Color.naldamSecondary)
                NavigationLink { SocialRequestView(person: person) } label: {
                    Label("인사 건네기", systemImage: "envelope")
                }.buttonStyle(NaldamPrimaryButtonStyle())
            }.padding(20)
        }
        .background(Color.appBackground)
        .navigationTitle("공개 프로필").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).naldamTabBarHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("신고·차단", systemImage: "flag") {
                    reportTarget = ContentReportTarget(personID: person.id, personName: person.name)
                }
            }
        }
        .sheet(item: $reportTarget) { ContentReportView(target: $0) }
    }
}
