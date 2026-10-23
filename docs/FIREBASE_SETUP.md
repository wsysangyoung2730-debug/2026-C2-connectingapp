# Apple 로그인 · 실제 1:1 채팅 설정

이 브랜치는 기존 봉투 UI에서 Apple 로그인, 공개 프로필, 대화 요청 및 1:1 텍스트 메시지를 연결합니다. 아래 프로젝트 설정이 완료되기 전에는 홈의 기록 기능을 계속 사용할 수 있고, 발견·대화에는 연결 준비 안내가 표시됩니다. 가짜 Firebase 설정 파일을 넣을 필요가 없습니다.

## 현재 설정 상태 · 2026-10-23

| 항목 | 확인한 상태 |
| --- | --- |
| Firebase 프로젝트 | `naldam-dev`, Spark 요금제. Google Analytics와 Gemini는 꺼둠 |
| Firebase iOS 앱 | `날담 iOS 개발`, Bundle ID `com.Tom.C2-connecting-app`으로 등록 |
| Firebase CLI | 사용자 승인 후 이 Mac에서 공식 CLI 로그인 완료 |
| Firebase Authentication | Apple 제공자 활성화. Services ID와 OAuth 코드 흐름 필드는 공란 |
| Apple Developer | Team `36545XSWN8`의 `Naldam` App ID를 Primary로 설정하고 Sign in with Apple 활성화 |
| Apple 개인키 | 이번 설정에서는 새 `.p8` 키를 만들지 않음 |
| Firestore | Standard edition, `(default)`, 서울 `asia-northeast3`. Production mode로 생성 |
| Firestore 접근 규칙 | 저장소의 `firebase/firestore.rules`를 콘솔 편집기에 입력하고 원문과 일치하는지 비교한 뒤 게시 완료 |
| 앱 설정 파일 | 공식 CLI의 `apps:sdkconfig IOS`로 받아 `C2_connecting app/GoogleService-Info.plist`에 저장. 프로젝트·Bundle ID 일치 및 Git 제외 확인 |
| 앱 빌드 | Simulator Debug 빌드 성공. 빌드된 앱에 설정 파일이 정확히 한 번 포함되며 원본 설정과 일치함을 확인 |
| Xcode 서명 Team | 앱의 Debug·Release 모두 `36545XSWN8`로 설정 |
| 실제 연결 검증 | 실제 Apple 로그인과 서로 다른 두 iPhone 사이의 메시지 전달은 아직 검증하지 않음 |

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
