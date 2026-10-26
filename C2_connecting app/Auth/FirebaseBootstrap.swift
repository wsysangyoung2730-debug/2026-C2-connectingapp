import Foundation
import FirebaseCore
import FirebaseFirestore

/// A missing project configuration leaves the private journal usable.
@MainActor
enum FirebaseBootstrap {
    private(set) static var configurationMessage: String?
    private static var attemptedConfiguration = false
    private static var configured = false

    @discardableResult
    static func configureIfAvailable() -> Bool {
        if attemptedConfiguration { return configured }
        attemptedConfiguration = true
        #if DEBUG
        if NaldamRuntime.isUITesting
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil {
            configurationMessage = "테스트에서는 실제 계정과 서버에 연결하지 않아요."
            return false
        }
        #endif
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path),
              valid(options: options, bundleID: Bundle.main.bundleIdentifier) else {
            configurationMessage = "아직 연결 설정을 준비 중이에요. 홈에서 나의 기록은 계속 사용할 수 있어요."
            return false
        }
        FirebaseApp.configure(options: options)
        // Conversations never survive sign-out in a shared on-disk Firebase cache.
        // The live store also removes its listeners and in-memory state on account change.
        let settings = Firestore.firestore().settings
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
        configured = true
        return true
    }

    static func valid(options: FirebaseOptions, bundleID: String?) -> Bool {
        guard let bundleID, options.bundleID == bundleID,
              let apiKey = options.apiKey, apiKey.hasPrefix("AIza"), apiKey.count > 20,
              let projectID = options.projectID, !projectID.isEmpty,
              !projectID.localizedCaseInsensitiveContains("YOUR_"),
              !projectID.localizedCaseInsensitiveContains("PLACEHOLDER"),
              options.googleAppID.hasPrefix("1:"), options.googleAppID.contains(":ios:") else { return false }
        return true
    }
}
