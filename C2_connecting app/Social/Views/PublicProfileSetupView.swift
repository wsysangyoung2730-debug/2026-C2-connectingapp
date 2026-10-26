import SwiftUI
import SwiftData

/// Social views never show a previous account's navigation or data during an auth change.
struct SocialAccessGate<Content: View>: View {
    @ObservedObject private var session = AppleSession.shared
    @ObservedObject private var store = LiveChatStore.shared
    @State private var showDeletion = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if session.userID == nil {
                SignInGateView()
            } else if store.deletionPending || store.suspended {
                VStack(spacing: 20) {
                    Text(store.deletionPending ? "계정 삭제를 마무리해 주세요" : "계정 이용이 제한되었어요").font(.title3.bold())
                    Text(store.deletionPending ? "삭제가 중단되어 새 대화를 시작할 수 없어요. 본인 확인 후 나머지 삭제를 이어갈 수 있어요." : "안전한 이용을 위해 연결 기능이 제한되어 있어요. 문의처에서 이의를 제기할 수 있어요.")
                        .font(.subheadline)
                    Button(store.deletionPending ? "삭제 계속하기" : "계정 삭제") { showDeletion = true }
                    NaldamLegalLinks()
                    Button("로그아웃") { session.signOut() }
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.appBackground)
            } else if store.currentUserID != session.userID || !store.profileLoaded {
                VStack(spacing: 16) {
                    ProgressView("프로필을 불러오고 있어요")
                    SocialStorageWarning(message: store.errorMessage)
                    if store.errorMessage != nil {
                        Button("다시 연결하기") { store.reconnect() }.frame(minHeight: 44)
                    }
                    Button("로그아웃") { session.signOut() }
                        .font(.footnote).frame(minHeight: 44)
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
            } else if store.publishedProfile == nil || store.publishedTermsVersion < CommunitySafety.termsVersion {
                PublicProfileSetupView(isEditing: store.publishedProfile != nil)
            } else {
                content()
            }
        }
        .fullScreenCover(isPresented: $showDeletion) { DeleteAccountView() }
    }
}

struct PublicProfileSetupView: View {
    @ObservedObject private var store = LiveChatStore.shared
    @ObservedObject private var session = AppleSession.shared
    @Query(sort: \InterestSelection.updatedAt, order: .reverse) private var selections: [InterestSelection]
    @AppStorage("profileName") private var localName = "나"
    @State private var name = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var useLocalInterests = false
    @State private var acceptedRules = false
    var isEditing = false
    var onSaved: (() -> Void)? = nil

    private var validName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var localInterests: [String] { InterestTagCatalog.selection(from: selections.first?.tags ?? []) }
    private var interests: [String] {
        if isEditing && !useLocalInterests { return store.publishedProfile?.interests ?? [] }
        return localInterests
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "envelope.open").font(.system(size: 38, weight: .light))
                    .foregroundStyle(Color.naldamAccent).padding(.top, 20)
                Text(isEditing ? "공개 프로필 수정" : "어떤 이름으로 만날까요?")
                    .font(.title2.weight(.bold)).foregroundStyle(Color.naldamInk)
                Text("발견과 대화에서 보여줄 이름과 관심사를 확인해 주세요.")
                    .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                VStack(alignment: .leading, spacing: 10) {
                    Text("이름").font(.headline)
                    TextField("1~12자 이름", text: $name)
                        .textContentType(.nickname).padding(16)
                        .background(Color.naldamPaper, in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: name) { _, value in
                            if value.count > 12 { name = String(value.prefix(12)) }
                        }.accessibilityIdentifier("social.profile.name")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("함께 좋아하는 것").font(.headline)
                    if interests.isEmpty {
                        Text("아직 담은 관심사가 없어요. 홈의 봉투에서 최대 6개를 고를 수 있어요.")
                            .font(.subheadline).foregroundStyle(Color.naldamSecondary)
                    } else {
                        SocialInterestTags(tags: interests)
                    }
                    if isEditing {
                        Toggle("홈의 관심사로 바꾸기", isOn: $useLocalInterests)
                            .font(.subheadline)
                        if useLocalInterests && localInterests.isEmpty {
                            Text("공개 관심사가 모두 비워져요.").font(.caption).foregroundStyle(Color.naldamAccent)
                        }
                    }
                    Text("관심사를 바꿨다면 이 화면에서 다시 공개해 주세요.")
                        .font(.caption).foregroundStyle(Color.naldamSecondary)
                }.naldamCard()
                Label("공개되는 정보는 이름과 관심사뿐이에요. 개인 기록과 기기에 저장한 사진은 공개되지 않아요.", systemImage: "lock")
                    .font(.footnote).foregroundStyle(Color.naldamSecondary)
                SocialStorageWarning(message: saveError ?? store.errorMessage)
                VStack(alignment: .leading, spacing: 12) {
                    Text("함께 지키는 약속").font(.headline)
                    Text(CommunitySafety.terms).font(.footnote).foregroundStyle(Color.naldamSecondary)
                    Toggle("이용약관과 커뮤니티 이용 수칙에 동의해요", isOn: $acceptedRules)
                        .font(.subheadline).accessibilityIdentifier("social.profile.terms")
                    Link("이용약관 읽기", destination: NaldamLegal.termsURL).font(.footnote)
                }.naldamCard()
                Button {
                    isSaving = true
                    saveError = nil
                    Task {
                        let saved = await store.publishProfile(name: validName, interests: interests)
                        isSaving = false
                        if saved { onSaved?() }
                        else { saveError = store.errorMessage ?? "공개 프로필을 저장하지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요." }
                    }
                } label: {
                    if isSaving { ProgressView().tint(.white) }
                    else { Text(isEditing ? "변경한 프로필 공개하기" : "이 프로필로 시작하기") }
                }
                .buttonStyle(NaldamPrimaryButtonStyle())
                .disabled(validName.isEmpty || validName.count > 12 || isSaving || !acceptedRules)
                .accessibilityIdentifier("social.profile.publish")
                if !isEditing {
                    Button("나중에 할게요 · 로그아웃") { session.signOut() }
                        .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                }
            }.padding(24).padding(.bottom, 40).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
        .navigationTitle("공개 프로필").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = store.publishedProfile?.name ?? localName
            acceptedRules = store.publishedTermsVersion >= CommunitySafety.termsVersion
        }
        .disabled(isSaving)
    }
}
