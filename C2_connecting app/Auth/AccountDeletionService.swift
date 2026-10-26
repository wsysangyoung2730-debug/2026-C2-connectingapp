import AuthenticationServices
import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Recent authentication is required before any destructive write. The server
/// marker freezes new contact and makes interrupted cleanup safe to retry.
@MainActor
final class AccountDeletionService: ObservableObject {
    @Published private(set) var isBusy = false
    @Published private(set) var completed = false
    @Published private(set) var progress = ""
    @Published var errorMessage: String?
    private var nonce: String?
    private var ownerID: String?

    var usesApple: Bool {
        guard AppleSession.shared.isConfigured else { return false }
        return Auth.auth().currentUser?.providerData.contains { $0.providerID == "apple.com" } ?? false
    }

    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        guard !isBusy, let user = Auth.auth().currentUser else { return }
        do {
            nonce = try AppleNonce.make(); ownerID = user.uid
            request.requestedScopes = []
            request.nonce = AppleNonce.sha256(nonce!)
            isBusy = true; errorMessage = nil
            progress = "Apple 계정으로 본인 확인 중이에요"
        } catch { errorMessage = "안전한 인증 요청을 만들지 못했어요. 다시 시도해 주세요." }
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) {
        guard let nonce, let ownerID else { return }
        self.nonce = nil
        Task {
            defer { isBusy = false }
            do {
                let authorization = try result.get()
                guard let user = Auth.auth().currentUser, user.uid == ownerID,
                      let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                      let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else {
                    throw DeletionError.identityChanged
                }
                let oauth = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: nil)
                _ = try await user.reauthenticate(with: oauth)
                progress = "Apple 연결을 해제하고 있어요"
                // Never pretend deletion succeeded when Apple token revocation fails.
                try await Auth.auth().revokeToken(withAuthorizationCode: code)
                try await erase(user)
            } catch {
                if (error as? ASAuthorizationError)?.code != .canceled { present(error) }
            }
        }
    }

    func deleteEmail(password: String) async {
        guard !isBusy, AppleSession.shared.isConfigured,
              let user = Auth.auth().currentUser, let email = user.email, !usesApple else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            progress = "비밀번호를 확인하고 있어요"
            _ = try await user.reauthenticate(with: EmailAuthProvider.credential(withEmail: email, password: password))
            try await erase(user)
        } catch { present(error) }
    }

    private func erase(_ user: User) async throws {
        let uid = user.uid
        guard Auth.auth().currentUser?.uid == uid else { throw DeletionError.identityChanged }
        _ = try await user.getIDTokenResult(forcingRefresh: true)
        let db = Firestore.firestore()
        let marker = db.collection("accountDeletions").document(uid)
        progress = "새 대화를 막고 삭제를 시작하고 있어요"
        _ = try await db.runTransaction { transaction, pointer -> Any? in
            do {
                let existing = try transaction.getDocument(marker)
                if !existing.exists {
                    transaction.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: marker)
                }
                return nil
            } catch { pointer?.pointee = error as NSError; return nil }
        }
        LiveChatStore.shared.suspendForDeletion()
        progress = "대화와 메시지를 삭제하고 있어요"
        // A marker on either member prevents message/room creation, so the
        // repeated server query converges even when the other device is online.
        while true {
            let rooms = try await db.collection("rooms").whereField("members", arrayContains: uid)
                .limit(to: 20).getDocuments(source: .server)
            if rooms.isEmpty { break }
            for room in rooms.documents {
                try await deleteDocuments(in: room.reference.collection("messages"))
                let batch = db.batch()
                for member in room.data()["members"] as? [String] ?? [] {
                    batch.deleteDocument(room.reference.collection("states").document(member))
                }
                batch.deleteDocument(room.reference)
                try await batch.commit()
            }
        }
        progress = "프로필과 계정을 삭제하고 있어요"
        try await deleteDocuments(in: db.collection("users").document(uid).collection("blocks"))
        try await deleteDocuments(in: db.collection("contentReports").document(uid).collection("items"))
        try await db.collection("profiles").document(uid).delete()
        try ChatLocalCache(userID: uid).erase()
        guard Auth.auth().currentUser?.uid == uid else { throw DeletionError.identityChanged }
        try await user.delete()
        completed = true
        progress = "계정과 서버의 대화 데이터를 삭제했어요"
    }

    private func deleteDocuments(in collection: CollectionReference) async throws {
        while true {
            let page = try await collection.limit(to: 200).getDocuments(source: .server)
            if page.isEmpty { return }
            let batch = collection.firestore.batch()
            page.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
    }

    private func present(_ error: Error) {
        let code = (error as NSError).code
        if code == AuthErrorCode.wrongPassword.rawValue || code == AuthErrorCode.invalidCredential.rawValue {
            errorMessage = "계정 정보를 확인하지 못했어요. 비밀번호 또는 Apple 계정을 확인해 주세요."
        } else {
            errorMessage = "삭제를 끝내지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요. 이미 삭제한 데이터는 복구되지 않으며, 나머지 삭제는 이어서 진행해요. 문제가 계속되면 문의해 주세요."
        }
    }
    private enum DeletionError: Error { case identityChanged }
}
