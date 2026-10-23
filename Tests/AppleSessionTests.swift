import Foundation
import FirebaseCore
import Testing
@testable import C2_connecting_app

@Suite("Apple 로그인 요청과 Firebase 설정")
@MainActor
struct AppleSessionTests {
    @Test("각 로그인 요청에 다른 256비트 nonce를 생성한다")
    func freshNonceForEachAttempt() throws {
        let first = try AppleNonce.make()
        let second = try AppleNonce.make()
        #expect(first.count == 64)
        #expect(second.count == 64)
        #expect(first != second)
        #expect(first.allSatisfy { "0123456789abcdef".contains($0) })
    }

    @Test("Apple에는 원본 nonce 대신 SHA256을 전달한다")
    func hashesNonce() {
        #expect(AppleNonce.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(AppleNonce.sha256("abc") != AppleNonce.sha256("abd"))
    }

    @Test("다른 앱의 설정이나 미완성 설정으로 Firebase를 시작하지 않는다")
    func validatesProjectIdentity() {
        let options = FirebaseOptions(googleAppID: "1:123456789:ios:abcdef012345", gcmSenderID: "123456789")
        options.bundleID = "com.Tom.C2-connecting-app"
        options.apiKey = "AIzaOnlyForLocalValidationTest000000000"
        options.projectID = "naldam-unit-test"
        #expect(FirebaseBootstrap.valid(options: options, bundleID: "com.Tom.C2-connecting-app"))
        #expect(!FirebaseBootstrap.valid(options: options, bundleID: "com.someone.else"))
        #expect(!FirebaseBootstrap.valid(options: options, bundleID: nil))
        options.projectID = "YOUR_PROJECT_ID"
        #expect(!FirebaseBootstrap.valid(options: options, bundleID: "com.Tom.C2-connecting-app"))
        options.projectID = "naldam-unit-test"
        options.apiKey = "placeholder"
        #expect(!FirebaseBootstrap.valid(options: options, bundleID: "com.Tom.C2-connecting-app"))
    }
}
