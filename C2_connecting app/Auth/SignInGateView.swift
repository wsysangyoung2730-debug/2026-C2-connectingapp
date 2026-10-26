import AuthenticationServices
import SwiftUI

struct SignInGateView: View {
    @ObservedObject private var session = AppleSession.shared
    @State private var showEmailSignIn = false

    private var showsSignInOptions: Bool {
        #if DEBUG
        // Exercise form UI while FirebaseBootstrap keeps all test traffic offline.
        if NaldamRuntime.isUITesting,
           ProcessInfo.processInfo.arguments.contains("-email-auth-ui-testing") { return true }
        #endif
        return session.isConfigured
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 46, weight: .ultraLight))
                    .foregroundStyle(Color.naldamAccent)
                    .padding(.top, 56)
                Text("작은 인사로 시작하는 사이")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.naldamInk)
                Text("계정으로 연결하고\n닮은 관심사를 가진 사람과 이야기를 나눠보세요.")
                    .font(.subheadline).lineSpacing(5)
                    .foregroundStyle(Color.naldamSecondary)
                    .multilineTextAlignment(.center)
                if showsSignInOptions {
                    SignInWithAppleButton(.continue, onRequest: session.prepare, onCompletion: session.complete)
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .disabled(session.isBusy || !session.isConfigured)
                        .accessibilityIdentifier("auth.appleSignIn")
                    HStack(spacing: 14) {
                        Rectangle().fill(Color.naldamLine).frame(height: 1)
                        Text("또는").font(.caption).foregroundStyle(Color.naldamSecondary)
                        Rectangle().fill(Color.naldamLine).frame(height: 1)
                    }.accessibilityHidden(true)
                    Button {
                        session.errorMessage = nil
                        showEmailSignIn = true
                    } label: {
                        Label("이메일로 로그인", systemImage: "envelope")
                    }
                    .buttonStyle(NaldamPrimaryButtonStyle())
                    .disabled(session.isBusy)
                    .accessibilityIdentifier("auth.emailSignIn")
                    if session.isBusy { ProgressView("계정에 연결하고 있어요") }
                } else {
                    Label(FirebaseBootstrap.configurationMessage ?? "연결 설정을 준비 중이에요.", systemImage: "envelope.badge")
                        .font(.subheadline).lineSpacing(4)
                        .foregroundStyle(Color.naldamSecondary)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityIdentifier("auth.configurationRequired")
                }
                NaldamLegalLinks()
                if let error = session.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Color.naldamAccent)
                        .accessibilityIdentifier("auth.error")
                }
                Text("나의 일기와 임시 저장은 공개되지 않아요.\n닉네임과 관심사는 공개 프로필에서 직접 확인해요.")
                    .font(.caption).lineSpacing(4)
                    .foregroundStyle(Color.naldamSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28).padding(.bottom, 100)
            .frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .background { NaldamEnvelopeBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView()
        }
    }
}
