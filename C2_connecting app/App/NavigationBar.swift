import SwiftUI

enum MainTab: String, Hashable, CaseIterable {
    case home, discover, conversations

    var title: String {
        switch self {
        case .home: "홈"
        case .discover: "발견"
        case .conversations: "대화"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .discover: "safari"
        case .conversations: "bubble.left.and.bubble.right"
        }
    }
}

private struct NaldamTabEnvironmentKey: EnvironmentKey {
    static let defaultValue = MainTab.home
}

private extension EnvironmentValues {
    var naldamTab: MainTab {
        get { self[NaldamTabEnvironmentKey.self] }
        set { self[NaldamTabEnvironmentKey.self] = newValue }
    }
}

private struct NaldamTabVisibilityKey: PreferenceKey {
    static let defaultValue: [MainTab: Bool] = [:]

    static func reduce(value: inout [MainTab: Bool], nextValue: () -> [MainTab: Bool]) {
        value.merge(nextValue(), uniquingKeysWith: { $0 || $1 })
    }
}

private struct NaldamTabVisibility: ViewModifier {
    @Environment(\.naldamTab) private var tab
    var hidden: Bool

    func body(content: Content) -> some View {
        content.preference(key: NaldamTabVisibilityKey.self, value: [tab: hidden])
    }
}

extension View {
    func naldamTabBarHidden(_ hidden: Bool = true) -> some View {
        modifier(NaldamTabVisibility(hidden: hidden))
    }
}

/// Navigation stacks retain their own history; the paper capsule sits on one continuous envelope floor.
struct NaldamTabRoot: View {
    @State private var selectedTab: MainTab = .home
    @State private var hiddenTabs: [MainTab: Bool] = [:]
    @ObservedObject private var socialStore = LiveChatStore.shared
    @ObservedObject private var session = AppleSession.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init() {
        #if DEBUG
        if let screen = NaldamRuntime.screenshotScreen, let tab = MainTab(rawValue: screen) {
            _selectedTab = State(initialValue: tab)
        }
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                Tab("홈", systemImage: "house", value: .home) {
                    NavigationStack { NaldamHomeView() }
                        .environment(\.naldamTab, .home)
                        .toolbar(.hidden, for: .tabBar)
                }
                Tab("발견", systemImage: "safari", value: .discover) {
                    NavigationStack { SocialAccessGate { DiscoveryView() } }
                        .id(session.userID ?? "signed-out")
                        .environment(\.naldamTab, .discover)
                        .toolbar(.hidden, for: .tabBar)
                }
                Tab("대화", systemImage: "bubble.left.and.bubble.right", value: .conversations) {
                    NavigationStack { SocialAccessGate { ConversationsView() } }
                        .id(session.userID ?? "signed-out")
                        .environment(\.naldamTab, .conversations)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if hiddenTabs[selectedTab] != true { floatingTabs }
        }
        .onPreferenceChange(NaldamTabVisibilityKey.self) { hiddenTabs = $0 }
        .onChange(of: session.userID) { _, _ in hiddenTabs = [:] }
        .background(Color.naldamEnvelope.ignoresSafeArea())
        .tint(.naldamAccent)
    }

    private var floatingTabs: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 21, weight: .regular))
                            .overlay(alignment: .topTrailing) {
                                if tab == .conversations && socialStore.unreadCount > 0 {
                                    Circle().fill(Color.naldamAccent)
                                        .frame(width: 7, height: 7).offset(x: 6, y: -2)
                                }
                            }
                        Text(tab.title).font(.caption.weight(selectedTab == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.naldamAccent : Color.naldamSecondary)
                    .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 78 : 50)
                    .background(selectedTab == tab ? Color.naldamSoft : Color.clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityValue(tab == .conversations && socialStore.unreadCount > 0 ? "새 인사와 읽지 않은 대화 \(socialStore.unreadCount)개" : "")
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        .padding(6)
        .background(Color.naldamPaper, in: Capsule())
        .overlay(Capsule().stroke(.white, lineWidth: 1))
        .shadow(color: Color.naldamAccent.opacity(0.1), radius: 14, y: 5)
        .frame(maxWidth: 430)
        .padding(.horizontal, 38)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 108 : 74)
        .background(Color.naldamEnvelope.ignoresSafeArea(edges: .bottom))
    }
}
