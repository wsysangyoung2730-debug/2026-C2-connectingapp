import SwiftUI

struct NaldamProfileView: View {
    @AppStorage("profileName") private var profileName = "나"
    @State private var editedName = ""
    @ObservedObject private var session = AppleSession.shared
    @ObservedObject private var store = LiveChatStore.shared
    @State private var showAccount = false
    @State private var showSignOut = false
    @AppStorage("profilePhotoJPEG") private var photoData = Data()
    @Environment(\.dismiss) private var dismiss
    private var validName: String { editedName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        VStack(spacing: 14) {
                            ProfilePhotoPicker(width: 88, height: 106)
                            if !photoData.isEmpty {
                                Button("프로필 사진 삭제", role: .destructive) { photoData = Data() }
                                    .font(.footnote).frame(minHeight: 44)
                            }
                            Text("사진은 선택하면 이 기기에 바로 저장돼요.")
                                .font(.caption).foregroundStyle(Color.naldamSecondary)
                        }
                        Spacer()
                    }.padding(.top, 20)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("이 기기에서 부를 이름").font(.headline)
                        TextField("이름", text: $editedName)
                            .textContentType(.nickname).padding(16)
                            .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 16))
                            .onChange(of: editedName) { _, value in
                                if value.count > 12 { editedName = String(value.prefix(12)) }
                            }.accessibilityIdentifier("profile.name")
                        Text("1~12자로 적어주세요. 공개 프로필 이름은 계정에서 따로 수정할 수 있어요.")
                            .font(.caption).foregroundStyle(Color.naldamSecondary)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Label("내 기록은 나만 보기", systemImage: "lock").font(.headline)
                        Text("질문에 쓴 답변과 임시 저장은 이 기기에 보관돼요. 발견이나 대화에 자동으로 공개되지 않아요.")
                        Divider()
                        Label(session.userID == nil ? "나와 닮은 관심사로 연결" : "계정에 연결됨", systemImage: "person.2").font(.headline)
                        Text("로그인하면 공개한 이름과 관심사로 친구를 찾고, 서로 수락한 대화에서 메시지를 주고받을 수 있어요. 프로필 사진은 이 기기에만 보관해요.")
                        Button(session.userID == nil ? "로그인하고 연결하기" : "공개 프로필 수정") { showAccount = true }
                            .frame(minHeight: 44).accessibilityIdentifier("profile.account")
                        if session.userID != nil {
                            Button("로그아웃", role: .destructive) { showSignOut = true }
                                .frame(minHeight: 44).accessibilityIdentifier("profile.signOut")
                        }
                        Divider()
                        Text("앱을 삭제하면 기기에만 저장한 일기·사진·초안이 사라질 수 있어요. 전송된 대화는 처음 로그인한 방식의 같은 계정으로 다시 연결하면 확인할 수 있어요.")
                            .foregroundStyle(Color.naldamSecondary)
                    }.font(.subheadline).lineSpacing(5).naldamCard()
                    NaldamLegalLinks()
                    HStack(spacing: 8) {
                        NaldamLogo(size: 20)
                        Text("날담 · 오늘의 나를 담다").font(.footnote)
                    }.foregroundStyle(Color.naldamSecondary)
                }
                .foregroundStyle(Color.naldamInk).padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .background(Color.appBackground)
            .navigationTitle("내 프로필").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { profileName = validName; dismiss() }
                        .disabled(validName.isEmpty).fontWeight(.semibold)
                }
            }
        }
        .tint(.naldamAccent).onAppear { editedName = profileName }
        .sheet(isPresented: $showAccount) {
            NavigationStack {
                SocialAccessGate {
                    PublicProfileSetupView(isEditing: true, onSaved: { showAccount = false })
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { showAccount = false }
                    }
                }
            }.id(session.userID ?? "signed-out").tint(.naldamAccent)
        }
        .confirmationDialog("로그아웃할까요?", isPresented: $showSignOut, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive) { session.signOut(); showAccount = false }
        } message: {
            Text("이 기기의 개인 기록은 남아 있어요. 대화는 처음 로그인한 방식의 같은 계정으로 다시 연결하면 볼 수 있어요.")
        }
    }
}
