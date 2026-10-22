import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAuth
import Foundation
import Security

@MainActor
final class AppleSession: ObservableObject {
    static let shared = AppleSession()

    @Published private(set) var userID: String?
    @Published var errorMessage: String?
    @Published private(set) var isBusy = false
    let isConfigured: Bool

    private var currentNonce: String?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var signInTask: Task<Void, Never>?

    private init() {
        isConfigured = FirebaseBootstrap.configureIfAvailable()
        guard isConfigured else { return }
        userID = Auth.auth().currentUser?.uid
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor [weak self] in
                // A queued callback may run after a subsequent sign-out/sign-in.
                // Publish the current identity, never an identity captured by an old callback.
                self?.userID = Auth.auth().currentUser?.uid
            }
        }
    }

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        errorMessage = nil
        guard isConfigured, !isBusy else { return }
        do {
            let nonce = try AppleNonce.make()
            currentNonce = nonce
            isBusy = true
            // Nickname is entered in the app; no email/name scope is needed.
            request.requestedScopes = []
            request.nonce = AppleNonce.sha256(nonce)
        } catch {
            currentNonce = nil
            errorMessage = "안전한 로그인 요청을 만들지 못했어요. 다시 시도해 주세요."
        }
    }

    func complete(_ result: Result<ASAuthorization, Error>) {
        guard isConfigured else { isBusy = false; return }
        let nonce = currentNonce
        currentNonce = nil
        switch result {
        case .failure(let error):
            isBusy = false
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Apple 로그인을 완료하지 못했어요. 다시 시도해 주세요."
            }
        case .success(let authorization):
            guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let token = apple.identityToken,
                  let idToken = String(data: token, encoding: .utf8), let nonce else {
                isBusy = false
                errorMessage = "로그인 응답을 확인하지 못했어요. 다시 시도해 주세요."
                return
            }
            let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: nil)
            signInTask = Task { [weak self] in
                guard let self else { return }
                defer { self.isBusy = false; self.signInTask = nil }
                do {
                    let result = try await Auth.auth().signIn(with: credential)
                    guard !Task.isCancelled else { return }
                    self.userID = result.user.uid
                } catch {
                    guard !Task.isCancelled else { return }
                    self.errorMessage = "계정에 연결하지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요."
                }
            }
        }
    }

    func signOut() {
        guard isConfigured, !isBusy else { return }
        do {
            try Auth.auth().signOut()
            userID = nil
            errorMessage = nil
            currentNonce = nil
        } catch {
            errorMessage = "로그아웃하지 못했어요. 다시 시도해 주세요."
        }
    }
}

enum AppleNonce {
    enum GenerationError: Error { case randomSourceUnavailable }

    static func make() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw GenerationError.randomSourceUnavailable }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
