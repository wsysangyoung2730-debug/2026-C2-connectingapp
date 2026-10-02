import SwiftUI

enum MainTab: String, Hashable {
    case home, discover, conversations
}

/// Native tabs provide Liquid Glass, safe areas, VoiceOver and Reduce Transparency.
struct NaldamTabRoot: View {
    @State private var selectedTab: MainTab = .home
    @ObservedObject private var socialStore = SocialStore.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("홈", systemImage: "house", value: .home) {
                NavigationStack { NaldamHomeView() }
            }
            Tab("발견", systemImage: "safari", value: .discover) {
                NavigationStack { DiscoveryView() }
            }
            Tab("대화", systemImage: "bubble.left.and.bubble.right", value: .conversations) {
                NavigationStack { ConversationsView() }
            }
            .badge(socialStore.unreadCount)
        }
        .tint(.naldamAccent)
    }
}
