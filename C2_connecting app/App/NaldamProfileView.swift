import SwiftUI

struct NaldamProfileView: View {
    @AppStorage("profileName") private var profileName = "나"
    @State private var editedName = ""
    @Environment(\.dismiss) private var dismiss
    private var validName: String { editedName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        NaldamAvatar(name: validName, size: 80)
                        Spacer()
                    }.padding(.top, 20)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("날담에서 부를 이름").font(.headline)
                        TextField("이름", text: $editedName)
                            .textContentType(.nickname).padding(16)
                            .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 16))
                            .onChange(of: editedName) { _, value in
                                if value.count > 12 { editedName = String(value.prefix(12)) }
                            }.accessibilityIdentifier("profile.name")
                        Text("1~12자로 적어주세요. 지금은 이 기기에만 저장돼요.")
                            .font(.caption).foregroundStyle(Color.naldamSecondary)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Label("내 기록은 나만 보기", systemImage: "lock").font(.headline)
                        Text("질문에 쓴 답변과 임시 저장은 이 기기에 보관돼요. 발견이나 대화에 자동으로 공개되지 않아요.")
                        Divider()
                        Label("연결은 아직 샘플 체험", systemImage: "person.2").font(.headline)
                        Text("발견의 인물과 이야기는 예시예요. 작성한 메시지는 외부로 전송되지 않으며, 실제 로그인·사용자 연결은 추후 서버 연결이 필요해요.")
                        Divider()
                        Text("앱을 삭제하면 기기에 저장한 데이터가 사라질 수 있어요. 현재 별도 계정 동기화나 복원 기능은 제공하지 않아요.")
                            .foregroundStyle(Color.naldamSecondary)
                    }.font(.subheadline).lineSpacing(5).naldamCard()
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
    }
}
