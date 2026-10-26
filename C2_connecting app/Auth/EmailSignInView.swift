import SwiftUI

/// Email is the account ID; credentials remain only in this view's transient state.
struct EmailSignInView: View {
    private enum Mode {
        case signIn, signUp, resetPassword

        var title: String {
            switch self {
            case .signIn: "이메일로 로그인"
            case .signUp: "이메일로 가입하기"
            case .resetPassword: "비밀번호 다시 설정하기"
            }
        }

        var action: String {
            switch self {
            case .signIn: "로그인"
            case .signUp: "계정 만들기"
            case .resetPassword: "재설정 메일 보내기"
            }
        }

        var description: String {
            switch self {
            case .signIn: "나의 계정으로 돌아와\n이어지는 이야기를 만나보세요."
            case .signUp: "이메일을 아이디로 사용해요.\n비밀번호는 8자 이상으로 만들어주세요."
            case .resetPassword: "가입할 때 사용한 이메일을 적어주세요.\n비밀번호를 바꾸는 방법을 안내해 드릴게요."
            }
        }
    }

    private enum Field: Hashable { case email }

    @ObservedObject private var session = AppleSession.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var validationMessage: String?
    @State private var attemptedCurrentMode = false
    @State private var requestInFlight = false
    @State private var resetSent = false
    @State private var requestTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?
    @State private var confirmingSignUp = false
    @ScaledMetric(relativeTo: .body) private var secureFieldHeight = 24.0

    private var cleanEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isBusy: Bool { session.isBusy || requestInFlight }
    private var canSubmit: Bool {
        !isBusy && !cleanEmail.isEmpty && (mode == .resetPassword || (confirmingSignUp ? !confirmation.isEmpty : !password.isEmpty))
    }
    private var errorMessage: String? {
        validationMessage ?? (attemptedCurrentMode ? session.errorMessage : nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    heading
                    VStack(alignment: .leading, spacing: 18) {
                        // Keep one secure input on screen at a time. This also gives
                        // the password confirmation enough room above the keyboard.
                        if confirmingSignUp {
                            Text(cleanEmail).font(.subheadline).foregroundStyle(Color.naldamSecondary)
                            confirmationField
                        } else {
                            emailField
                            if mode != .resetPassword { passwordField }
                        }
                        statusMessage
                        Button(action: submit) {
                            HStack(spacing: 10) {
                                if isBusy { ProgressView().tint(.white) }
                                Text(isBusy ? "잠시만 기다려주세요" : (mode == .signUp && !confirmingSignUp ? "다음" : mode.action))
                            }
                        }
                        .buttonStyle(NaldamPrimaryButtonStyle())
                        .disabled(!canSubmit)
                        .accessibilityIdentifier("auth.email.submit")
                    }
                    modeActions
                    if mode != .resetPassword {
                        Text("Apple 로그인과 이메일 로그인은 자동으로 연결되지 않아요. 기존 대화는 처음 로그인한 방식으로 연결해 주세요.")
                            .font(.caption).lineSpacing(4)
                            .foregroundStyle(Color.naldamSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        NaldamLegalLinks()
                    }
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 36)
                .frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { NaldamEnvelopeBackground() }
            .foregroundStyle(Color.naldamInk)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { clearPasswords(); dismiss() }
                        .disabled(isBusy)
                        .accessibilityIdentifier("auth.email.close")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focusedField != nil {
                HStack {
                    Spacer()
                    Button("입력 완료") { focusedField = nil }
                        .font(.body.weight(.semibold)).frame(minHeight: 44)
                }.padding(.horizontal, 24).background(Color.appBackground)
            }
        }
        .tint(.naldamAccent)
        .interactiveDismissDisabled(isBusy)
        .onChange(of: session.userID) { _, userID in
            if userID != nil { clearPasswords(); dismiss() }
        }
        .onDisappear {
            clearPasswords()
            requestTask?.cancel()
            requestTask = nil
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: mode == .resetPassword ? "key" : "envelope.open")
                .font(.system(size: 38, weight: .ultraLight))
                .foregroundStyle(Color.naldamAccent)
                .accessibilityHidden(true)
            Text(mode == .signIn ? "다시 만나 반가워요" : mode == .signUp ? "작은 인사를 시작해요" : "다시 연결할 수 있어요")
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(confirmingSignUp ? "비밀번호를 한 번 더 입력하면\n나의 계정을 만들 수 있어요." : mode.description)
                .font(.subheadline).lineSpacing(5)
                .foregroundStyle(Color.naldamSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("아이디 (이메일)").font(.subheadline.weight(.semibold))
            TextField("name@example.com", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(mode == .resetPassword ? .send : .done)
                .focused($focusedField, equals: .email)
                .onSubmit {
                    if mode == .resetPassword { submit() }
                    else { focusedField = nil }
                }
                .modifier(AccountFieldStyle())
                .disabled(isBusy)
                .accessibilityLabel("아이디, 이메일 주소")
                .accessibilityIdentifier("auth.email.address")
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("비밀번호").font(.subheadline.weight(.semibold))
            AccountPasswordField(text: $password, placeholder: mode == .signUp ? "8자 이상 입력" : "비밀번호 입력",
                                 isEnabled: !isBusy,
                                 accessibilityID: "auth.email.password", accessibilityName: "비밀번호", onFocus: { focusedField = nil }, onSubmit: submit)
                .id(mode)
                .frame(height: secureFieldHeight).modifier(AccountFieldStyle())
        }
    }

    private var confirmationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("비밀번호 확인").font(.subheadline.weight(.semibold))
            AccountPasswordField(text: $confirmation, placeholder: "비밀번호를 한 번 더 입력",
                                 isEnabled: !isBusy,
                                 accessibilityID: "auth.email.confirmPassword", accessibilityName: "비밀번호 확인", onFocus: { focusedField = nil }, onSubmit: submit)
                .frame(height: secureFieldHeight).modifier(AccountFieldStyle())
        }
    }

    @ViewBuilder private var statusMessage: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle")
                .font(.footnote).lineSpacing(4)
                .foregroundStyle(Color.naldamAccent)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("auth.email.error")
        } else if resetSent {
            Label(EmailAuthErrorPresentation.resetConfirmation, systemImage: "envelope.badge")
                .font(.footnote).lineSpacing(4)
                .foregroundStyle(Color.naldamSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("auth.email.resetConfirmation")
        } else if attemptedCurrentMode, let message = session.infoMessage {
            Text(message).font(.footnote).lineSpacing(4)
                .foregroundStyle(Color.naldamSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("auth.email.info")
        }
    }

    private var modeActions: some View {
        VStack(spacing: 2) {
            if mode == .signIn {
                Button("비밀번호를 잊으셨나요?") { changeMode(.resetPassword) }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("auth.email.forgotPassword")
                Button("처음 오셨나요? 이메일로 가입하기") { changeMode(.signUp) }
                    .fontWeight(.semibold).frame(minHeight: 44)
                    .accessibilityIdentifier("auth.email.createAccount")
            } else {
                if confirmingSignUp {
                    Button("비밀번호 다시 입력하기") {
                        focusedField = nil
                        confirmingSignUp = false
                        clearPasswords()
                        validationMessage = nil
                    }.frame(minHeight: 44)
                }
                Button("로그인으로 돌아가기") { changeMode(.signIn) }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("auth.email.backToSignIn")
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .disabled(isBusy)
    }

    private func changeMode(_ next: Mode) {
        guard !isBusy else { return }
        focusedField = nil
        confirmingSignUp = false
        clearPasswords()
        validationMessage = nil
        attemptedCurrentMode = false
        resetSent = false
        mode = next
    }

    private func clearPasswords() {
        confirmingSignUp = false
        password = ""
        confirmation = ""
    }

    private func submit() {
        guard canSubmit else { return }
        validationMessage = nil
        attemptedCurrentMode = false
        resetSent = false
        guard EmailAuthenticationValidation.email(cleanEmail) != nil else {
            validationMessage = "아이디로 사용할 이메일 주소를 확인해 주세요."
            focusedField = .email
            return
        }
        if mode == .signUp {
            guard EmailAuthenticationValidation.acceptsNewPassword(password) else {
                validationMessage = "비밀번호는 8자 이상, 4,096자 이내로 입력해 주세요."
                focusedField = nil
                return
            }
            if !confirmingSignUp {
                focusedField = nil
                confirmingSignUp = true
                return
            }
            guard password == confirmation else {
                validationMessage = "두 비밀번호가 같지 않아요. 다시 확인해 주세요."
                focusedField = nil
                return
            }
        }
        focusedField = nil
        requestInFlight = true
        attemptedCurrentMode = true
        let submittedMode = mode
        let submittedEmail = cleanEmail
        let submittedPassword = password
        requestTask = Task { @MainActor in
            defer {
                clearPasswords()
                requestInFlight = false
                requestTask = nil
            }
            let succeeded: Bool
            switch submittedMode {
            case .signIn:
                succeeded = await session.signIn(email: submittedEmail, password: submittedPassword)
            case .signUp:
                succeeded = await session.signUp(email: submittedEmail, password: submittedPassword)
            case .resetPassword:
                succeeded = await session.sendPasswordReset(email: submittedEmail)
            }
            guard !Task.isCancelled else { return }
            if succeeded, submittedMode == .resetPassword { resetSent = true }
            else if succeeded { dismiss() }
        }
    }
}

private struct AccountFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.naldamLine, lineWidth: 1))
    }
}
