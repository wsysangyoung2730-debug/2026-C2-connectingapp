# Apple 로그인 · 실제 1:1 채팅 설정

이 브랜치는 기존 봉투 UI에서 Apple 로그인, 공개 프로필, 대화 요청 및 1:1 텍스트 메시지를 연결합니다. 아래 프로젝트 설정이 완료되기 전에는 홈의 기록 기능을 계속 사용할 수 있고, 발견·대화에는 연결 준비 안내가 표시됩니다. 가짜 Firebase 설정 파일을 넣을 필요가 없습니다.

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

1. [Apple Developer의 Identifiers](https://developer.apple.com/account/resources/identifiers/list)에서 위 Bundle ID의 App ID를 찾거나 생성합니다.
2. App ID에서 **Sign in with Apple**을 활성화합니다. 기존 앱과 그룹을 구성하지 않았다면 기본 App ID로 구성합니다.
3. Xcode → 앱 타깃 → **Signing & Capabilities**에서 본인의 Team을 선택합니다. 이 브랜치에는 `Sign in with Apple` entitlement가 이미 추가되어 있습니다. 서명 오류가 있으면 해당 Team의 App ID와 프로비저닝 프로필에 기능이 활성화됐는지 확인합니다.
4. Firebase 공식 가이드의 전체 설정 순서에 따라 Apple Developer에서 위 App ID와 연결된 **Services ID**와 **Sign in with Apple 키**를 만듭니다. 웹 인증 설정의 Return URL은 `https://<PROJECT_ID>.firebaseapp.com/__/auth/handler`입니다. Services ID, Team ID, Key ID와 내려받은 `.p8` 키를 준비합니다.
5. Firebase Console → **Authentication → Sign-in method → Apple**을 활성화합니다. Services ID를 입력하고 OAuth 코드 흐름 설정에 Team ID, Key ID, `.p8` 개인키를 등록한 뒤 저장합니다. 이 앱에서는 네이티브 Apple 인증 응답을 Firebase에 전달합니다. 개인키는 콘솔에만 등록하고 앱이나 Git에는 넣지 않습니다.
6. 실기기의 설정에서 iCloud에 로그인하고, 테스트 Apple 계정의 이중 인증이 활성화되어 있는지 확인합니다.

[Firebase 공식 Apple 로그인 설정](https://firebase.google.com/docs/auth/ios/apple) · [Apple의 Sign in with Apple 활성화](https://developer.apple.com/help/account/capabilities/enable-sign-in-with-apple/)

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

`<PROJECT_ID>`는 Firebase 프로젝트 설정의 실제 프로젝트 ID로 바꿉니다. 앱에 넣은 plist의 `PROJECT_ID`와 같아야 합니다. 인덱스가 생성 중이면 Firebase Console에서 완료될 때까지 기다립니다. 이 작업은 이번 코드 작성 과정에서 실제 프로젝트에 자동 배포하지 않았습니다.

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
