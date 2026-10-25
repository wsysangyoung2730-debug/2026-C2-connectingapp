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
    @Published var infoMessage: String?
    @Published private(set) var isBusy = false
    let isConfigured: Bool

    private var currentNonce: String?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var signInTask: Task<Void, Never>?
    private var emailClient: any EmailAuthClient = FirebaseEmailAuthClient()

    /// Unit tests inject a client without configuring Firebase or touching the keychain.
    init(emailClient: any EmailAuthClient, isConfigured: Bool) {
        self.emailClient = emailClient
        self.isConfigured = isConfigured
    }

    private init() {
        isConfigured = FirebaseBootstrap.configureIfAvailable()
        #if DEBUG
        if NaldamRuntime.isStoreScreenshot {
            userID = "screenshot-owner"
            return
        }
        #endif
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
        guard isConfigured, !isBusy else { return }
        errorMessage = nil
        infoMessage = nil
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

    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        guard beginEmailOperation() else { return false }
        defer { isBusy = false }
        guard let email = EmailAuthenticationValidation.email(email) else {
            errorMessage = "이메일 주소를 확인해 주세요."
            return false
        }
        guard EmailAuthenticationValidation.acceptsSignInPassword(password) else {
            errorMessage = "비밀번호를 입력해 주세요."
            return false
        }
        do {
            userID = try await emailClient.signIn(email: email, password: password)
            return true
        } catch {
            errorMessage = EmailAuthErrorPresentation.message(for: error, operation: .signIn)
            return false
        }
    }

    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        guard beginEmailOperation() else { return false }
        defer { isBusy = false }
        guard let email = EmailAuthenticationValidation.email(email) else {
            errorMessage = "이메일 주소를 확인해 주세요."
            return false
        }
        guard EmailAuthenticationValidation.acceptsNewPassword(password) else {
            errorMessage = "비밀번호는 8자 이상, 4,096자 이내로 입력해 주세요."
            return false
        }
        do {
            // Firebase signs the new account in as part of account creation.
            userID = try await emailClient.signUp(email: email, password: password)
            return true
        } catch {
            errorMessage = EmailAuthErrorPresentation.message(for: error, operation: .signUp)
            return false
        }
    }

    @discardableResult
    func sendPasswordReset(email: String) async -> Bool {
        guard beginEmailOperation() else { return false }
        defer { isBusy = false }
        guard let email = EmailAuthenticationValidation.email(email) else {
            errorMessage = "이메일 주소를 확인해 주세요."
            return false
        }
        do {
            try await emailClient.sendPasswordReset(email: email)
            infoMessage = EmailAuthErrorPresentation.resetConfirmation
            return true
        } catch {
            // Match the success response even when enumeration protection is disabled server-side.
            if EmailAuthErrorPresentation.isUnknownResetAccount(error) {
                infoMessage = EmailAuthErrorPresentation.resetConfirmation
                return true
            }
            errorMessage = EmailAuthErrorPresentation.message(for: error, operation: .reset)
            return false
        }
    }

    private func beginEmailOperation() -> Bool {
        guard !isBusy else { return false }
        errorMessage = nil
        infoMessage = nil
        guard isConfigured else {
            errorMessage = "아직 계정 연결을 준비 중이에요. 잠시 후 다시 시도해 주세요."
            return false
        }
        isBusy = true
        return true
    }

    func complete(_ result: Result<ASAuthorization, Error>) {
        // A canceled/late Apple callback must not unlock an in-flight email request.
        guard isConfigured, let nonce = currentNonce else { return }
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
                  let idToken = String(data: token, encoding: .utf8) else {
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
            infoMessage = nil
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
