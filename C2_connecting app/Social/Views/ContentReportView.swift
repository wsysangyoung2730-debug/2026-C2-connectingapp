import FirebaseAuth
import FirebaseFirestore
import SwiftUI

struct ContentReportView: View {
    let target: ContentReportTarget
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ContentReportReason.harassment
    @State private var details = ""
    @State private var alsoBlock = true
    @State private var sending = false
    @State private var received = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if received {
                    Section {
                        Label("신고를 접수했어요", systemImage: "checkmark.circle")
                        Text("24시간 이내 확인하고 필요한 조치를 진행해요. 신고자 정보는 상대방에게 공개하지 않아요.")
                        if alsoBlock { Text("이 프로필을 차단했어요. 대화 탭에서 차단을 관리할 수 있어요.") }
                        Button("확인") { dismiss() }.accessibilityIdentifier("report.done")
                    }
                } else {
                    Section("신고 대상 · \(target.personName)") {
                        Picker("신고 이유", selection: $reason) {
                            ForEach(ContentReportReason.allCases) { Text($0.title).tag($0) }
                        }
                        TextField("추가 설명 (선택, 500자 이내)", text: $details, axis: .vertical)
                            .lineLimit(3...6).onChange(of: details) { _, value in
                                if value.count > 500 { details = String(value.prefix(500)) }
                            }
                        Toggle("이 프로필도 차단하기", isOn: $alsoBlock)
                    }
                    Section {
                        Text("신고한 프로필이나 메시지의 식별 정보와 신고 내용을 운영자에게 전달해요. 운영자는 신고 확인에 필요한 콘텐츠를 확인할 수 있어요.")
                            .font(.footnote)
                        Button { Task { await submit() } } label: {
                            if sending { ProgressView("신고를 보내고 있어요") } else { Text("신고 보내기") }
                        }.disabled(sending).accessibilityIdentifier("report.submit")
                        if let errorMessage { Text(errorMessage).foregroundStyle(Color.naldamAccent) }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Color.appBackground)
            .navigationTitle("신고하기").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() }.disabled(sending) } }
        }.tint(.naldamAccent).interactiveDismissDisabled(sending)
    }

    private func submit() async {
        guard !sending, AppleSession.shared.isConfigured,
              let uid = Auth.auth().currentUser?.uid, uid != target.personID else { return }
        sending = true; errorMessage = nil
        defer { sending = false }
        let db = Firestore.firestore()
        let id = target.personID + "__" + (target.messageID.isEmpty ? "profile" : target.messageID)
        let ref = db.collection("contentReports").document(uid).collection("items").document(id)
        let fields: [String: Any] = ["targetUserID": target.personID, "roomID": target.roomID,
            "messageID": target.messageID, "reason": reason.rawValue, "details": details,
            "status": "pending", "createdAt": FieldValue.serverTimestamp()]
        let block = alsoBlock
        let targetID = target.personID
        do {
            _ = try await db.runTransaction { transaction, pointer -> Any? in
                do {
                    let existing = try transaction.getDocument(ref)
                    if !existing.exists { transaction.setData(fields, forDocument: ref) }
                    if block {
                        transaction.setData(["createdAt": FieldValue.serverTimestamp()],
                            forDocument: db.collection("users").document(uid).collection("blocks").document(targetID))
                    }
                    return nil
                } catch { pointer?.pointee = error as NSError; return nil }
            }
            received = true
        } catch { errorMessage = "신고를 접수하지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요." }
    }
}
