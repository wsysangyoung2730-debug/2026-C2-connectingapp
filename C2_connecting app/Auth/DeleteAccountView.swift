import AuthenticationServices
import SwiftUI

struct DeleteAccountView: View {
    @StateObject private var deletion = AccountDeletionService()
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: deletion.completed ? "checkmark.circle" : "person.crop.circle.badge.minus")
                        .font(.system(size: 42, weight: .light)).foregroundStyle(Color.naldamAccent)
                    Text(deletion.completed ? "계정을 삭제했어요" : "계정을 영구 삭제할까요?").font(.title2.bold())
                    if deletion.completed {
                        Text("로그인 계정, 공개 프로필, 참여한 대화와 메시지, 이 계정의 대화 초안을 삭제했어요. 이 기기의 개인 일기와 관심사·사진은 계정과 별개로 남아 있어요.")
                        Button("확인") { dismiss() }.buttonStyle(NaldamPrimaryButtonStyle())
                            .accessibilityIdentifier("account.delete.done")
                    } else {
                        Text("로그인 계정과 공개 프로필, 참여한 1:1 대화와 모든 메시지를 삭제해요. 상대방의 앱에서도 해당 대화가 사라지며 복구할 수 없어요. 상대방이 별도로 저장한 사본은 삭제되지 않아요.")
                        Text("개인 일기·관심사·사진은 로그인 계정과 별개로 이 기기에 보관되어 남아 있어요. 신고 처리에 필요한 정보와 삭제 재시도용 표식은 처리 완료 후 30일 안에 정리해요.")
                            .font(.footnote).foregroundStyle(Color.naldamSecondary)
                        Toggle("삭제 범위를 확인했으며 영구 삭제에 동의해요", isOn: $confirmed)
                            .accessibilityIdentifier("account.delete.confirm")
                        if deletion.usesApple {
                            Text("본인 확인 후 Apple 연결을 해제하고 삭제해요.").font(.footnote)
                            SignInWithAppleButton(.continue, onRequest: deletion.prepareApple, onCompletion: deletion.completeApple)
                                .signInWithAppleButtonStyle(.black).frame(height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .disabled(!confirmed || deletion.isBusy)
                        } else {
                            SecureField("현재 비밀번호", text: $password)
                                .textContentType(.password).padding(16)
                                .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 14))
                                .accessibilityIdentifier("account.delete.password")
                            Button("계정 영구 삭제", role: .destructive) {
                                let value = password; password = ""
                                Task { await deletion.deleteEmail(password: value) }
                            }.buttonStyle(NaldamPrimaryButtonStyle())
                                .disabled(!confirmed || password.isEmpty || deletion.isBusy)
                                .accessibilityIdentifier("account.delete.submit")
                        }
                        if deletion.isBusy { ProgressView(deletion.progress) }
                        if let error = deletion.errorMessage { Text(error).font(.footnote).foregroundStyle(Color.naldamAccent) }
                        NaldamLegalLinks()
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(Color.appBackground).foregroundStyle(Color.naldamInk)
            .navigationTitle("계정 삭제").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() }.disabled(deletion.isBusy) } }
        }
        .tint(.naldamAccent).interactiveDismissDisabled(deletion.isBusy)
        .onDisappear {
            password = ""
            if !deletion.completed { LiveChatStore.shared.reconnect() }
        }
    }
}
