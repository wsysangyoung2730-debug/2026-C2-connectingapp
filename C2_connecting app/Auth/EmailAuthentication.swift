import FirebaseAuth
import Foundation

enum EmailAuthenticationValidation {
    static let minimumPasswordLength = 8
    static let maximumPasswordLength = 4_096

    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func email(_ email: String) -> String? {
        let normalized = normalizedEmail(email)
        guard normalized.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else { return nil }
        return normalized
    }

    static func acceptsSignInPassword(_ password: String) -> Bool {
        // Existing accounts may use an older password policy. Never trim a password.
        !password.isEmpty
    }

    static func acceptsNewPassword(_ password: String) -> Bool {
        (minimumPasswordLength...maximumPasswordLength).contains(password.count)
    }
}

/// Credentials live only in the duration of the request; no password cache is created.
@MainActor
protocol EmailAuthClient {
    func signIn(email: String, password: String) async throws -> String
    func signUp(email: String, password: String) async throws -> String
    func sendPasswordReset(email: String) async throws
}

@MainActor
struct FirebaseEmailAuthClient: EmailAuthClient {
    func signIn(email: String, password: String) async throws -> String {
        try await Auth.auth().signIn(withEmail: email, password: password).user.uid
    }

    func signUp(email: String, password: String) async throws -> String {
        try await Auth.auth().createUser(withEmail: email, password: password).user.uid
    }

    func sendPasswordReset(email: String) async throws {
        let auth = Auth.auth()
        auth.languageCode = "ko"
        try await auth.sendPasswordReset(withEmail: email)
    }
}

enum EmailAuthErrorPresentation {
    enum Operation: Equatable { case signIn, signUp, reset }

    static let resetConfirmation = "입력한 이메일로 재설정할 수 있는 계정이 있다면 안내 메일을 보내드려요. 받은편지함과 스팸함을 확인해 주세요."

    static func isUnknownResetAccount(_ error: Error) -> Bool {
        code(for: error) == .userNotFound
    }

    static func message(for error: Error, operation: Operation) -> String {
        switch code(for: error) {
        case .networkError:
            return "인터넷 연결을 확인하고 다시 시도해 주세요."
        case .tooManyRequests, .quotaExceeded:
            return "요청이 잠시 많아졌어요. 조금 뒤에 다시 시도해 주세요."
        case .operationNotAllowed:
            return "지금은 이메일로 연결할 수 없어요. 잠시 후 다시 시도해 주세요."
        case .weakPassword where operation == .signUp, .passwordDoesNotMeetRequirements where operation == .signUp:
            return "비밀번호가 가입 기준에 맞지 않아요. 8자 이상으로 영문·숫자·기호를 함께 사용해 주세요."
        default:
            // Do not reveal whether this email is registered, disabled or linked to Apple.
            switch operation {
            case .signIn:
                return "이메일 또는 비밀번호를 확인해 주세요. 계속 어렵다면 비밀번호 재설정을 이용해 주세요."
            case .signUp:
                return "계정을 만들지 못했어요. 입력 내용을 확인하거나 로그인·비밀번호 재설정을 이용해 주세요."
            case .reset:
                return "재설정 요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    private static func code(for error: Error) -> AuthErrorCode? {
        let error = error as NSError
        guard error.domain == AuthErrors.domain else { return nil }
        return AuthErrorCode(rawValue: error.code)
    }
}
