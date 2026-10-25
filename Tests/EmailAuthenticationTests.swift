import AuthenticationServices
import FirebaseAuth
import Foundation
import Testing
@testable import C2_connecting_app

@Suite("이메일 계정 인증")
@MainActor
struct EmailAuthenticationTests {
    @Test("이메일만 공백과 대소문자를 정리하고 잘못된 주소를 거부한다")
    func normalizesEmail() {
        #expect(EmailAuthenticationValidation.email(" \n Test+Tag@EXAMPLE.COM \t") == "test+tag@example.com")
        for email in ["", " ", "user", "user@", "@example.com", "a b@example.com", "a@@example.com", "a@example"] {
            #expect(EmailAuthenticationValidation.email(email) == nil)
        }
    }

    @Test("가입은 8~4096자이며 로그인은 기존의 짧은 비밀번호도 허용한다")
    func validatesPasswordByOperation() {
        #expect(!EmailAuthenticationValidation.acceptsSignInPassword(""))
        #expect(EmailAuthenticationValidation.acceptsSignInPassword("123456"))
        #expect(!EmailAuthenticationValidation.acceptsNewPassword("1234567"))
        #expect(EmailAuthenticationValidation.acceptsNewPassword("12345678"))
        #expect(EmailAuthenticationValidation.acceptsNewPassword(String(repeating: "a", count: 4096)))
        #expect(!EmailAuthenticationValidation.acceptsNewPassword(String(repeating: "a", count: 4097)))
    }

    @Test("로그인 시 비밀번호를 변경하지 않고 성공한 UID를 게시한다")
    func signInPreservesPassword() async {
        let client = FakeEmailAuthClient()
        client.onSignIn = { email, password in
            #expect(email == "person@example.com")
            #expect(password == " 123 ")
            return "signed-in-user"
        }
        let session = AppleSession(emailClient: client, isConfigured: true)
        #expect(await session.signIn(email: " Person@EXAMPLE.COM ", password: " 123 "))
        #expect(session.userID == "signed-in-user")
        #expect(!session.isBusy)
        #expect(session.errorMessage == nil)
        #expect(session.infoMessage == nil)
    }

    @Test("회원가입 검증 실패는 서버를 호출하지 않으며 성공 시 바로 로그인한다")
    func signUpValidationAndSession() async {
        let client = FakeEmailAuthClient()
        let session = AppleSession(emailClient: client, isConfigured: true)
        #expect(!(await session.signUp(email: "person@example.com", password: "1234567")))
        #expect(client.signUpCount == 0)
        #expect(session.userID == nil)
        #expect(!session.isBusy)
        #expect(await session.signUp(email: " Person@EXAMPLE.COM ", password: "safe-test-password"))
        #expect(client.signUpCount == 1)
        #expect(client.lastEmail == "person@example.com")
        #expect(session.userID == "test-user")
        #expect(session.errorMessage == nil)
    }

    @Test("진행 중에는 다른 로그인·회원가입·재설정 요청을 시작하지 않는다")
    func preventsOverlappingOperations() async {
        let client = FakeEmailAuthClient()
        let session = AppleSession(emailClient: client, isConfigured: true)
        client.onSignIn = { _, _ in
            #expect(session.isBusy)
            #expect(!(await session.signIn(email: "other@example.com", password: "password")))
            #expect(!(await session.signUp(email: "other@example.com", password: "password")))
            #expect(!(await session.sendPasswordReset(email: "other@example.com")))
            session.complete(.failure(ASAuthorizationError(.canceled)))
            #expect(session.isBusy)
            return "first-user"
        }
        #expect(await session.signIn(email: "first@example.com", password: "password"))
        #expect(client.signInCount == 1)
        #expect(client.signUpCount == 0)
        #expect(client.resetCount == 0)
        #expect(session.userID == "first-user")
        #expect(!session.isBusy)
    }

    @Test("재설정 응답은 계정 존재 여부를 구분하지 않는다")
    func passwordResetHidesAccountExistence() async {
        let client = FakeEmailAuthClient()
        let session = AppleSession(emailClient: client, isConfigured: true)
        #expect(await session.sendPasswordReset(email: " Person@EXAMPLE.COM "))
        let successMessage = session.infoMessage
        #expect(client.lastEmail == "person@example.com")
        client.resetError = authError(.userNotFound)
        #expect(await session.sendPasswordReset(email: "unknown@example.com"))
        #expect(session.infoMessage == successMessage)
        #expect(session.errorMessage == nil)
        #expect(session.userID == nil)
        #expect(!session.isBusy)
    }

    @Test("계정 관련 오류를 같은 문구로 안내하고 서버 오류 본문을 노출하지 않는다")
    func safeErrorMessages() {
        let expected = EmailAuthErrorPresentation.message(for: authError(.wrongPassword), operation: .signIn)
        for code in [AuthErrorCode.userNotFound, .userDisabled, .invalidCredential, .accountExistsWithDifferentCredential] {
            #expect(EmailAuthErrorPresentation.message(for: authError(code), operation: .signIn) == expected)
        }
        let privateError = NSError(domain: AuthErrors.domain, code: AuthErrorCode.emailAlreadyInUse.rawValue,
                                   userInfo: [NSLocalizedDescriptionKey: "secret-person@example.com exists"])
        let message = EmailAuthErrorPresentation.message(for: privateError, operation: .signUp)
        #expect(!message.contains("secret-person"))
        #expect(message == EmailAuthErrorPresentation.message(for: NSError(domain: "unknown", code: 0), operation: .signUp))
    }

    @Test("네트워크 오류 후 재시도할 수 있고 미설정 상태에서는 인증을 호출하지 않는다")
    func failureAndMissingConfiguration() async {
        let client = FakeEmailAuthClient()
        client.onSignIn = { _, _ in throw authError(.networkError) }
        let session = AppleSession(emailClient: client, isConfigured: true)
        #expect(!(await session.signIn(email: "person@example.com", password: "password")))
        #expect(!session.isBusy)
        #expect(session.errorMessage?.contains("인터넷") == true)
        client.onSignIn = nil
        #expect(await session.signIn(email: "person@example.com", password: "password"))
        #expect(session.errorMessage == nil)

        let disconnectedClient = FakeEmailAuthClient()
        let disconnected = AppleSession(emailClient: disconnectedClient, isConfigured: false)
        #expect(!(await disconnected.signIn(email: "person@example.com", password: "password")))
        #expect(disconnectedClient.signInCount == 0)
        #expect(disconnected.errorMessage != nil)
        #expect(!disconnected.isBusy)
    }

    private func authError(_ code: AuthErrorCode) -> NSError {
        NSError(domain: AuthErrors.domain, code: code.rawValue)
    }
}

@MainActor
private final class FakeEmailAuthClient: EmailAuthClient {
    var signInCount = 0
    var signUpCount = 0
    var resetCount = 0
    var lastEmail: String?
    var onSignIn: ((String, String) async throws -> String)?
    var resetError: Error?

    func signIn(email: String, password: String) async throws -> String {
        signInCount += 1
        lastEmail = email
        if let onSignIn { return try await onSignIn(email, password) }
        return "test-user"
    }

    func signUp(email: String, password: String) async throws -> String {
        signUpCount += 1
        lastEmail = email
        return "test-user"
    }

    func sendPasswordReset(email: String) async throws {
        resetCount += 1
        lastEmail = email
        if let resetError { throw resetError }
    }
}
