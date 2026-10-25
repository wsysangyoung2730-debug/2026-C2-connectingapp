# Apple·이메일 로그인 · 실제 1:1 채팅 설정

이 브랜치는 기존 봉투 UI에서 Apple 로그인, 공개 프로필, 대화 요청 및 1:1 텍스트 메시지를 연결합니다. 아래 프로젝트 설정이 완료되기 전에는 홈의 기록 기능을 계속 사용할 수 있고, 발견·대화에는 연결 준비 안내가 표시됩니다. 가짜 Firebase 설정 파일을 넣을 필요가 없습니다.

## 현재 설정 상태 · 2026-10-26

| 항목 | 확인한 상태 |
| --- | --- |
| Firebase 프로젝트 | `naldam-dev`, Spark 요금제. Google Analytics와 Gemini는 꺼둠 |
| Firebase iOS 앱 | `날담 iOS 개발`, Bundle ID `com.Tom.C2-connecting-app`으로 등록 |
| Firebase CLI | 사용자 승인 후 이 Mac에서 공식 CLI 로그인 완료 |
| Firebase Authentication | Apple 및 이메일/비밀번호 제공자 활성화. 이메일 링크 로그인은 사용하지 않음. Apple Services ID와 OAuth 코드 흐름 필드는 공란 |
| Apple Developer | Team `36545XSWN8`의 `Naldam` App ID를 Primary로 설정하고 Sign in with Apple 활성화 |
| Apple 개인키 | 이번 설정에서는 새 `.p8` 키를 만들지 않음 |
| Firestore | Standard edition, `(default)`, 서울 `asia-northeast3`. Production mode로 생성 |
| Firestore 접근 규칙 | 저장소의 `firebase/firestore.rules`를 콘솔 편집기에 입력하고 원문과 일치하는지 비교한 뒤 게시 완료 |
| 앱 설정 파일 | 공식 CLI의 `apps:sdkconfig IOS`로 받아 `C2_connecting app/GoogleService-Info.plist`에 저장. 프로젝트·Bundle ID 일치 및 Git 제외 확인 |
| 앱 빌드 | Simulator Debug 빌드 성공. 빌드된 앱에 설정 파일이 정확히 한 번 포함되며 원본 설정과 일치함을 확인 |
| Xcode 서명 Team | 앱의 Debug·Release 모두 `36545XSWN8`로 설정 |
| 실제 연결 검증 | 두 이메일 계정으로 실제 서버의 프로필·요청·수락·실시간 메시지 왕복·로그아웃 후 접근 차단·재로그인 복원 확인. 실제 Apple 로그인과 서로 다른 두 iPhone 사이의 전달은 별도 미검증 |

콘솔·Apple App ID 설정, 앱 설정 파일 저장과 빌드 포함 확인을 마쳤습니다. **실기기 서명·프로비저닝 확인 → 실제 Apple 로그인 → 두 기기 간 채팅 검증**이 남아 있습니다. 아래 절차는 다른 개발 환경에서 재현하거나 이후 설정을 갱신할 때도 사용합니다.

## 이번 단계에 포함된 것

- Firebase Authentication: Apple 계정의 UID로 사용자를 구분합니다. 앱은 Apple 이메일·실명을 요청하지 않습니다.
- Cloud Firestore: 사용자가 확인한 공개 닉네임·관심사, 요청, 두 사람의 메시지와 읽음 상태를 저장합니다.
- 관심사는 서로 다른 최대 6개, 각 관심사는 앱에서 5글자 이내로 입력합니다.
- 개인 일기·임시 기록과 홈의 프로필 사진은 기기에 남습니다. 개인 기록이 공개 프로필이나 채팅으로 자동 업로드되지 않습니다.
- 프로필 사진 업로드, 사진 메시지, 푸시 알림은 이번 단계에 포함되지 않습니다. 따라서 Cloud Storage·FCM 설정은 지금 필요하지 않습니다.

Firebase Apple SDK는 공식 릴리스 `13.1.0`으로 고정했습니다. Auth, Firestore, Core만 앱에 연결합니다.

## 1. Firebase 프로젝트와 iOS 앱 등록

1. [Firebase Console](https://console.firebase.google.com/)에서 프로젝트를 만듭니다. Google Analytics는 이번 기능에 필수가 아닙니다.
2. 프로젝트 설정에서 **iOS 앱 추가**를 선택합니다.
3. 현재 Xcode 앱 타깃의 Bundle Identifier는 **`com.Tom.C2-connecting-app`**입니다. 대소문자까지 동일하게 등록합니다. 이미 Apple 개발자 계정에서 사용하는 다른 Bundle ID가 있다면 Xcode·Firebase·Apple App ID 세 곳을 같은 값으로 맞춥니다.
4. `GoogleService-Info.plist`를 내려받아 **앱 소스 폴더 `C2_connecting app/`** 안에 넣습니다. `.xcodeproj`와 나란한 최상위 폴더가 아닙니다.
5. 이 프로젝트는 Xcode의 동기화 폴더를 사용합니다. 앱 타깃의 Resources에 파일이 한 번 포함되는지 확인합니다. 파일 이름에 `(1)` 같은 접미사가 없어야 합니다.

파일은 Git에서 제외되어 있습니다. 다른 팀원도 같은 환경의 설정 파일을 각자 받아야 합니다. 다른 Bundle ID의 파일이나 미완성 파일은 앱에서 연결하지 않습니다. 서비스 계정 JSON·Apple `.p8` 개인키는 앱에 포함하거나 저장소에 올리지 않습니다.

## 2. Apple 로그인 활성화

Apple로 로그인은 **Apple Developer Program에 가입된 팀**의 설정이 필요합니다.

### 현재 앱: 네이티브 iOS 로그인

이 앱은 Apple의 `AuthenticationServices`에서 받은 ID token과 nonce를 Firebase에 전달합니다. 이 네이티브 로그인만 연결할 때는 Firebase의 **Services ID, Apple Team ID, Key ID, Private Key 필드를 비워둘 수 있습니다.** Xcode의 서명 Team은 별도로 반드시 선택해야 합니다. [Firebase의 Apple 플랫폼 전용 설정 안내](https://firebase.google.com/docs/auth/unity/apple)

1. [Apple Developer의 Identifiers](https://developer.apple.com/account/resources/identifiers/list)에서 위 Bundle ID의 App ID를 찾거나 생성합니다.
2. Account Holder 또는 Admin 권한으로 App ID의 **Sign in with Apple**을 활성화하고 Configure를 누릅니다. 기존 앱과 그룹을 구성하지 않은 신규 앱이면 **Primary App ID**로 설정하고 저장합니다.
3. Xcode → 앱 타깃 → **Signing & Capabilities**에서 해당 App ID를 소유한 Apple Developer Program의 Team을 선택합니다. 이 브랜치에는 `Sign in with Apple` entitlement가 이미 추가되어 있습니다. 자동 서명을 사용하고, 필요하면 기기를 등록합니다. App ID의 기능을 변경했다면 프로비저닝 프로필도 갱신해야 합니다.
4. Firebase Console → **Authentication → Sign-in method → Apple**을 활성화하고 저장합니다. 이번 네이티브 iOS 로그인에서는 Services ID와 OAuth 코드 흐름 설정을 비워둡니다.
5. 실기기의 설정에서 iCloud에 로그인하고, 테스트 Apple 계정의 이중 인증을 활성화합니다. 현재 프로젝트의 최소 지원 버전은 **iOS 26.2**입니다. 일반 Run으로 앱을 실행해 확인합니다. 자동 UI 테스트는 실제 Firebase 연결을 의도적으로 비활성화합니다.

[Firebase의 네이티브 Apple 로그인 구현](https://firebase.google.com/docs/auth/ios/apple) · [Apple의 Sign in with Apple 활성화](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/) · [Apple의 실기기 실행 설정](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple)

### 이후 웹·Android 로그인을 연결할 때

웹·Android에서 브라우저를 거치는 Apple 로그인에는 **Services ID, 도메인·Return URL과 OAuth 코드 흐름 설정**을 추가합니다.

1. Apple Developer에서 위 Primary App ID에 연결된 **Services ID**를 만듭니다. 웹 인증 설정에 Firebase 도메인과 Return URL `https://<PROJECT_ID>.firebaseapp.com/__/auth/handler`를 등록합니다.
2. 해당 App ID에 연결된 **Sign in with Apple 키**를 만들고 Team ID, Key ID, 내려받은 `.p8` 개인키를 준비합니다.
3. Firebase의 Apple 제공자에 Services ID를 입력하고 OAuth 코드 흐름 설정에 Team ID, Key ID, 개인키를 등록합니다. 개인키는 앱이나 Git에 넣지 않습니다.

[Apple의 웹 인증 설정](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web/) · [Firebase의 웹 Apple 로그인 설정](https://firebase.google.com/docs/auth/web/apple)

### 이후 네이티브 앱의 계정 삭제·Apple 토큰 철회를 연결할 때

일반 로그인 때 비워둔 OAuth 설정과 토큰 철회에 필요한 서버 인증 설정은 구분합니다. Firebase를 통해 Apple authorization code를 교환하고 토큰을 철회하려면 **Apple Team ID, Key ID, `.p8` 개인키를 OAuth 코드 흐름 설정에 등록**해야 합니다. 개인키는 앱에 넣지 않습니다.

Services ID는 웹 인증용 식별자이며, 네이티브 앱의 Bundle ID와 같은 값으로 취급하지 않습니다. 다만 현재 [Firebase iOS 공식 문서의 Token revocation 절](https://firebase.google.com/docs/auth/ios/apple#token_revocation)은 Services ID와 OAuth 코드 흐름을 함께 설정하도록 안내합니다. 따라서 네이티브 철회에 Services ID가 언제나 필수이거나 언제나 불필요하다고 여기서 단정하지 않습니다. 철회 기능을 구현할 때 해당 시점의 Firebase 요구 사항과 앱 등록 정보를 확인하고, 네이티브 authorization code로 실기기 철회가 성공하는지 검증합니다. 이번 로그인 연결을 위해 웹용 Services ID를 미리 만들 필요는 없습니다.

앱에서는 재인증으로 받은 Apple authorization code를 `Auth.auth().revokeToken(withAuthorizationCode:)`에 전달한 뒤 Firebase 계정과 관련 데이터를 삭제하는 처리까지 구현해야 합니다. 콘솔의 OAuth 설정만으로 계정 삭제 기능이 완성되지는 않습니다.

## 이메일·비밀번호 로그인

Firebase Console → Authentication → 로그인 방법에서 **이메일/비밀번호**를 사용 설정합니다. 이메일 링크 로그인은 필요하지 않습니다. 기존 Apple 로그인은 유지합니다.

앱에서 이메일을 아이디로 사용합니다. 가입 비밀번호는 8~4,096자이며 확인 입력이 일치해야 합니다. 로그인은 기존 계정과의 호환을 위해 가입 길이 규칙을 재적용하지 않습니다. 비밀번호는 Firebase Authentication에만 전달하고 앱 저장소·Firestore·로그에 저장하지 않습니다. 재설정 안내는 해당 이메일의 계정 존재 여부를 구분하지 않습니다. Apple 계정과 이메일 계정의 자동 연결 기능은 제공하지 않습니다.

단위 테스트 및 일반 UI 테스트는 실제 서버에 연결하지 않습니다. `-naldam-ui-testing -email-auth-ui-testing`은 DEBUG에서 이메일 폼만 표시하며 Firebase 차단은 유지합니다.

실제 서버 검증 스크립트는 명시적으로 선택할 때만 실행하며, 두 계정과 검토용 프로필·채팅을 생성합니다. 일반 `npm test`에 포함하지 않습니다. 인증 파일은 저장소 밖의 비공개 경로를 지정해야 하며 파일 권한은 0600입니다. 같은 파일을 사용하면 기존 검토 계정으로 재검증합니다.

```sh
NALDAM_LIVE_PROJECT=naldam-dev node firebase/scripts/check-live-email-chat.mjs \
  'C2_connecting app/GoogleService-Info.plist' \
  /absolute/private/path/email-review-accounts.json
```

2026-10-26 실제 서버에서 두 계정 인증, 프로필 공개, 비로그인 접근 거부, 수락 전 메시지 거부, 발신자 자기 수락 거부, 수신자 수락, 양방향 실시간 수신, 읽음 상태 분리, 로그아웃·재로그인을 검증했습니다. 테스트 주소는 예약된 `.invalid` 도메인을 사용하므로 메일 수신 테스트용이 아닙니다. 재설정 메일 수신·비밀번호 변경과 Apple 실기기 로그인은 이 검증에 포함하지 않습니다. 심사용 비밀번호를 Git·공개 이슈에 올리지 않습니다.

같은 날 정상 서명된 Naldam QA 시뮬레이터에서 실제 앱 화면으로 A 로그인·메시지 전송 → 로그아웃 → B 로그인·수신·답장 → 로그아웃 → A 재로그인·답장 복원을 확인했습니다. `LiveEmailChatUITests`는 테스트 러너에 `NALDAM_LIVE_EMAIL_ACCOUNTS_JSON`을 명시적으로 제공할 때만 실행하고, 평소에는 건너뜁니다. 앱에는 샘플·인증 우회 인수를 전달하지 않습니다. 총 단위 테스트 47개, 이메일 폼 UI 테스트 2개, 실제 계정 UI 테스트 1개가 통과했습니다.

실제 Firebase 인증은 iOS 보안 저장소를 사용하므로 시뮬레이터도 정상 서명해야 합니다. `CODE_SIGNING_ALLOWED=NO` 빌드는 오프라인 단위·폼 테스트에만 사용합니다. 실제 계정 UI 테스트는 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`로 빌드한 후 실행했습니다. 테스트 러너 설정과 결과에는 인증 입력 정보가 포함될 수 있으므로 공개하지 않습니다. 검증 후 심사용 비밀번호를 새 값으로 갱신하고 동일 UID로 재로그인을 확인했습니다.

개인정보처리방침 버전 1.1에는 이메일 주소와 Firebase 인증 처리를 반영했고, 앱 매니페스트에는 사용자 연결·앱 기능 목적·추적 없음으로 이메일 주소를 선언합니다. 2026-10-26 App Store Connect에도 같은 내용으로 이메일 주소를 추가하여 총 8개 데이터 유형을 게시했습니다.

App Store Connect의 비공개 심사 정보에는 전용 이메일 계정과 로그인·대화 확인 절차를 저장했습니다. 두 번째 검토 계정은 심사 메모에서만 제공합니다. 이 계정들은 실제 Firebase 인증과 권한 규칙을 사용하며, 개인 계정이나 인증을 우회하는 계정이 아닙니다. 스토어 설명도 Apple 또는 이메일 로그인으로 수정했습니다. 심사 정보 저장과 실제 심사 제출은 별개의 단계입니다.

이메일 인증을 포함한 버전 1.0 빌드 2는 2026-10-26 App Store Connect 업로드에 성공했습니다. 외부 바이너리인 FirebaseFirestoreInternal, absl, grpc, grpcpp, openssl_grpc의 dSYM 누락 경고가 있었고 앱 자체 dSYM은 아카이브에 포함됐습니다. 외부 라이브러리 내부의 충돌 분석에는 제약이 남습니다. 실제 Apple 로그인, 두 실기기 간 검증, TestFlight 설치, 계정 삭제·신고 기능 등 출시 전 확인 항목은 GitHub 이슈 #20에서 추적합니다.

[Firebase 이메일 인증 구현](https://firebase.google.com/docs/auth/ios/password-auth)

## 3. Firestore 만들고 접근 규칙 배포

1. Firebase Console → **Firestore Database → Create database**를 엽니다.
2. Standard edition의 기본 데이터베이스 **`(default)`**를 만듭니다. 이용자가 주로 한국에 있다면 콘솔에서 서울 리전 제공 여부를 확인해 가까운 리전을 선택합니다. 위치는 생성 후 쉽게 바꾸는 설정이 아니므로 확인하고 선택합니다.
3. **Production mode**로 생성합니다. 누구나 읽고 쓰는 테스트 규칙으로 실제 사용자 데이터를 운영하지 않습니다.
4. 저장소의 `firebase/` 폴더에서 의존성을 설치하고, 로그인한 Firebase 계정으로 정확한 프로젝트에 규칙과 인덱스를 배포합니다.

```sh
cd firebase
npm ci
npx firebase login
npx firebase deploy --only firestore:rules,firestore:indexes --project <PROJECT_ID>
```

`<PROJECT_ID>`는 Firebase 프로젝트 설정의 실제 프로젝트 ID로 바꿉니다. 앱에 넣은 plist의 `PROJECT_ID`와 같아야 합니다. 인덱스가 생성 중이면 Firebase Console에서 완료될 때까지 기다립니다. 위 명령은 이후 CLI로 규칙과 인덱스를 갱신할 때의 절차입니다. **2026-10-23에는 CLI 자동 배포 대신 Firebase 콘솔에서 `firebase/firestore.rules`와 입력 내용을 비교한 뒤 실제 개발 프로젝트에 규칙을 게시했습니다.**

규칙은 로그인한 사용자, 본인의 프로필, 대화 참여자, 요청 수신자 및 차단 상태를 확인합니다. UI에서 버튼을 숨기는 것만으로 권한을 처리하지 않습니다. 일기와 프로필 사진을 담는 컬렉션은 만들지 않습니다.

[Firestore 시작하기](https://firebase.google.com/docs/firestore/quickstart) · [보안 규칙 배포](https://firebase.google.com/docs/firestore/security/get-started)

## 4. 앱에서 확인할 순서

1. Xcode에서 패키지 다운로드가 끝나면 서로 다른 Apple 계정을 사용하는 iPhone 두 대에 앱을 설치합니다.
2. 로그인하지 않은 상태에서도 홈에서 개인 기록을 작성할 수 있는지 확인합니다.
3. A와 B가 각각 발견 또는 대화 탭에서 Apple로 로그인합니다. 공개 프로필에서 닉네임과 서로 겹치는 관심사를 확인하고 저장합니다.
4. 발견에서 상대를 찾아 A가 인사를 건넵니다. **A에게는 자신의 요청을 수락하는 버튼이 없어야 합니다.**
5. B의 대화 탭에서 받은 인사를 수락합니다. 그 후 두 기기에서 메시지를 주고받습니다.
6. 네트워크를 끊어 메시지를 작성했을 때 서버 전송 완료로 잘못 표시하지 않는지, 재연결 또는 재시도로 전달되는지 확인합니다.
7. 대화를 닫고 앱을 다시 열어 대화가 유지되는지, 읽음 표시와 목록이 갱신되는지 확인합니다.
8. 한 계정에서 차단하고 상대의 전송이 제한되는지 확인합니다. 로그아웃 후 다른 계정으로 로그인했을 때 이전 계정의 대화·초안이 표시되지 않아야 합니다.

이번 단계의 실시간 채팅은 앱을 사용 중일 때 확인합니다. 앱을 완전히 닫았을 때의 푸시 알림은 후속 작업입니다. Firebase 설정이 없는 로컬 빌드 및 UI 테스트는 실제 사용자나 Firebase 서버에 연결하지 않습니다.

## 에뮬레이터 규칙 테스트

실제 프로젝트를 사용하지 않고 `firebase/`의 JavaScript 테스트로 권한 규칙을 검증할 수 있습니다. 해당 폴더의 README에 적힌 Node·Java 요구 사항을 준비한 뒤 실행합니다.

```sh
cd firebase
npm ci
npm test
```

테스트 프로젝트 ID는 `demo-naldam-chat`이며 프로덕션 프로젝트에 데이터를 쓰지 않습니다. 이 설정은 규칙 테스트용입니다. 앱의 Apple 로그인 자체를 에뮬레이터에서 대신 인증하는 기능은 포함하지 않습니다.

## 운영 전에 이어서 준비할 것

공개 배포 전에는 신고·운영 대응, 계정 및 관련 데이터 삭제, 이용약관·개인정보 처리방침을 완성해야 합니다. 알림을 추가할 때는 FCM/APNs와 신뢰할 수 있는 서버에서 메시지 알림을 보내는 처리가 별도로 필요합니다. Firebase 사용량·할당량은 콘솔에서 확인하며, 이번 단계가 무제한 무료 이용을 보장하는 것은 아닙니다.

[Firebase Apple SDK 릴리스](https://firebase.google.com/support/release-notes/ios) · [Firestore 사용량과 한도](https://firebase.google.com/docs/firestore/quotas)
