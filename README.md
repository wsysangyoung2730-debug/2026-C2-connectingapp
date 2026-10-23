# 날담

하루의 질문에 답하며 나를 기록하고, 관심사를 통해 연결되는 iOS 앱입니다. 봉투 기반 PAPER UI를 유지하며 **Apple 로그인과 Firebase Firestore 1:1 채팅**을 연결했습니다. 실제 서비스 사용에는 [Firebase·Apple 설정](docs/FIREBASE_SETUP.md)이 필요합니다. 설정 파일이 없어도 홈과 개인 기록은 사용할 수 있습니다.

## 구현한 화면

- **홈**: 오늘의 질문, 저장·이어쓰기 상태, 실제 주간 기록 현황, 최근 기록 5개와 개별 기록 이동, 프로필 편집
- **봉투 풀업**: 접힘·중간·펼침의 3단계, 중앙 프로필 사진과 좌우 3칸씩 고유 관심사 6개, 검색과 5글자 이내 직접 입력, 명시적 저장과 취소
- **기록**: 날짜별 작성·수정·삭제, 임시 저장, 달력, 내용 검색, 원래 질문 보존
- **발견**: Apple 로그인 후 이름·관심사를 확인해 공개, 공통 관심사 수로 정렬한 실제 프로필과 인사 요청
- **대화**: 상대 수락 후 1:1 텍스트 채팅, 실시간 목록과 읽지 않은 대화 표시, 질문 제안, 전송 상태·재시도, 차단·해제, 대화 보관과 복원
- **브랜드**: 날담 PAPER 로고와 앱 아이콘, 아이보리 종이와 갈색 봉투 배경, 흰색 캡슐 탭바

메인 메뉴는 홈·발견·대화입니다. 개인 기록은 발견이나 대화에 자동으로 공유되지 않습니다. 질문은 현재 7개의 질문을 날짜별로 순환하며, 이미 저장한 기록은 당시 질문을 유지합니다.

## 실행

Xcode에서 `C2_connecting app.xcodeproj`를 열고 공유 스킴 `C2_connecting app`을 선택합니다. 최소 버전은 기존 설정과 동일한 iOS 26.2입니다. Firebase Apple SDK 13.1.0을 Swift Package Manager로 가져옵니다. 홈 실행에는 서버 설정이 필요하지 않으며, 실제 로그인과 채팅에는 본인 Firebase 프로젝트와 Apple 개발자 설정이 필요합니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'C2_connecting app.xcodeproj' -scheme 'C2_connecting app' \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/naldam-build CODE_SIGNING_ALLOWED=NO build
```

실기기 실행은 Xcode에서 본인의 서명 팀을 설정합니다. 앱 표시 이름만 날담으로 바꿨으며, 기존 설치의 저장소 연속성을 위해 번들 식별자는 유지했습니다.

## 데이터 보관

프로필 사진은 시스템 사진 선택기로 고른 이미지만 읽어 비율을 유지한 최대 600픽셀 JPEG로 변환한 뒤 기기 설정에 보관합니다. 사진은 선택 즉시 반영되며 내 프로필에서 변경·삭제할 수 있습니다. 직접 추가하는 관심사는 앞뒤 공백과 해시 표시를 정리한 뒤 5글자 이내인지 검사하고, 저장 시 중복을 제거합니다.

개인 기록과 홈 관심사는 SwiftData, 로컬 프로필 사진·이름과 온보딩 여부는 UserDefaults에 보관합니다. 공개 프로필은 확인 화면에서 이름·관심사만 Firestore에 저장합니다. 개인 일기·사진은 자동 업로드하지 않습니다. 기존 기록 스키마와 파일은 유지합니다.

채팅방·메시지·계정별 읽음 상태는 Firestore에 보관합니다. 메시지는 서버가 확인한 뒤에만 전송됨으로 표시하며, 실패한 메시지는 같은 ID로 재시도해 중복을 방지합니다. 초안과 미전송 메시지만 계정별 보호된 로컬 파일에 저장합니다. 로그아웃 시 구독과 화면 상태를 비우며 Firestore 디스크 캐시는 사용하지 않습니다. 손상된 로컬 파일은 덮어쓰지 않습니다.

기존 샘플 대화 파일은 서버로 올리지 않으며 실제 대화에 섞이지 않습니다. 개인 기록은 계정 동기화 대상이 아니므로 앱 삭제 시 사라질 수 있습니다. 앱이 꺼졌을 때의 푸시 알림은 다음 단계입니다.

## 테스트

공유 스킴에 `NaldamTests`와 `NaldamUITests`가 연결되어 있습니다. Xcode의 Test 동작으로 실행하거나 설치된 시뮬레이터 이름을 지정합니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'C2_connecting app.xcodeproj' -scheme 'C2_connecting app' \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/naldam-build CODE_SIGNING_ALLOWED=NO test
```

단위 테스트는 기존 기록 동작, 계정별 초안 분리, 미전송 메시지 복원, 입력 경계, 로그인 nonce와 설정 검증을 확인합니다. UI 테스트는 홈·봉투·기록·사진과 로그인 전 소셜 진입을 확인합니다. 실제 Apple 로그인과 두 기기 메시지 왕복은 별도 프로젝트 설정 후 실기기에서 확인해야 합니다.

UI 테스트는 Debug 전용 인자로 메모리 기록 저장소를 사용하고 Firebase 연결을 비활성화합니다. 사용자의 일반 기록 저장소를 초기화하지 않습니다. 서버 권한은 `firebase/`에서 `npm ci && npm test`로 독립된 로컬 Firestore 에뮬레이터에서 검사합니다. 실제 프로젝트에는 테스트 데이터를 쓰지 않습니다.

사진 선택 테스트는 시뮬레이터 사진 보관함에 테스트 이미지가 있어야 합니다. 빈 보관함이라면 실행할 시뮬레이터에 프로젝트 아이콘을 추가합니다. 실제 기기의 개인 사진은 테스트에 사용하지 않습니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl addmedia \
  '<시뮬레이터 UDID>' 'C2_connecting app/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
```

2026년 10월 3일 iPhone 17 Pro 시뮬레이터에서 단위 테스트 20개와 UI 테스트 4개가 모두 통과했습니다. [실제 구현 화면과 검증 범위](design/implementation/2026-10-03/README.md)를 함께 보관했습니다.

## 코드 구성

| 위치 | 역할 |
| --- | --- |
| `App` | 앱 진입, 디자인 공통 요소, 탭, 프로필 |
| `Main` | 질문 카드와 실제 기록 기반 홈 |
| `Quiz` | 기록 모델, 저장 처리, 편집과 달력 |
| `Interests` | 봉투 형태, 풀업 상태, 관심사 편집 |
| `Auth` | Apple 로그인, Firebase 설정 검증과 로그인 안내 |
| `Social` | 실제 프로필·요청·채팅 저장소와 기존 PAPER 화면, 이전 로컬 파일 호환 코드 |
| `firebase` | Firestore 규칙, 에뮬레이터 권한 테스트 |
| `Tests`, `UITests` | 데이터·UI 회귀 테스트 |
| `design` | 브랜드·UI 시안과 실제 구현 캡처 |

기존 C2 일부 컴포넌트는 참고용으로 남아 있으나 새 진입 흐름에서는 사용하지 않습니다. 앱 아이콘은 `scripts/render-app-icon.swift`의 원본 벡터 경로로 재생성할 수 있습니다.

## 다음 출시 작업

### 2026년 10월 23일 제출 준비 상태

- 개인정보처리방침: <https://connectingapp-site.vercel.app/>
- 지원·신고 안내: <https://connectingapp-site.vercel.app/#contact>
- App Store Connect: [날담 - 하루를 담는 기록](https://appstoreconnect.apple.com/apps/6826260707/distribution/ios/version/inflight), 한국어, 대한민국만 배포, 무료, 승인 후 수동 출시로 저장했습니다. 심사 제출과 빌드 업로드는 아직 하지 않았습니다.
- 연령 설문 결과는 글로벌 13+, 대한민국 15+입니다. 사용자 작성 콘텐츠와 소셜·채팅 기능, 드문 욕설 및 음주 언급 가능성, 자기 관리 주제를 반영했습니다. 나이 확인이나 보호자 제어 기능이 있다고 신고하지 않았습니다.
- 운영 기준은 계정 삭제 요청 7일 이내 처리, 문의 해결 후 30일 뒤 삭제, 유해 콘텐츠 신고 24시간 이내 확인입니다. 운영자 연락처는 공개 사이트에 있고, 심사 전용 전화번호는 App Store Connect에만 저장했습니다.
- 이번 변경 전 기준 단위 테스트 32개와 Firestore 에뮬레이터 권한 테스트 16개가 통과했습니다. 새 캡처용 코드의 Debug 빌드도 성공했습니다. 캡처 UI 테스트는 테스트 러너 시작 단계에서 멈춰 취소했으므로 통과로 기록하지 않습니다.
- 앱의 로그인 안내·온보딩·내 프로필에서 공개 개인정보처리방침과 지원 안내를 열 수 있습니다. 자체 UserDefaults 사용 이유(CA92.1)를 개인정보 매니페스트에 추가했습니다.
- iPhone 17 Pro Max(1320×2868) 7장, iPad Pro 13형(2064×2752) 6장을 실제 시뮬레이터에서 캡처하고 육안 확인했습니다. PNG 원본과 투명 채널이 없는 스토어용 JPG, 전체 ZIP을 준비했습니다. 브라우저 도구 연결 중단으로 App Store 이미지 업로드 완료는 확인하지 못했습니다.

스토어 화면은 Debug 전용 `-naldam-ui-testing -naldam-seeded-ui -naldam-store-screenshot` 인자로 가상의 계정·관심사·대화를 메모리에 넣어 실제 SwiftUI 화면을 캡처합니다. 이 모드에서는 Firebase에 연결하지 않습니다. Release에는 캡처 계정과 진입 분기가 포함되지 않습니다. `-naldam-screen=home|envelope|interests|journal|discover|conversations|chat`으로 화면별 캡처를 재현할 수 있습니다. 채팅 직접 진입 캡처에는 이전 화면이 없어 뒤로가기 버튼이 표시되지 않습니다. 최종 심사 자료는 실제 탐색 흐름과 기능 보완을 마친 빌드로 다시 확인합니다.

**미완료:** 실제 Apple 계정 두 개로 로그인·요청 수락·메시지 왕복 검증, 앱 안에서 시작하는 계정 삭제 및 Apple 토큰 해제, 콘텐츠 신고·필터·운영 대응, 최종 수집 정보 표시, 서명된 배포 빌드와 TestFlight 검증. 공개 개인정보처리방침이나 에뮬레이터 테스트만으로 이 항목들을 완료 처리하지 않습니다. [출시 준비 이슈 #20](https://github.com/wsysangyoung2730-debug/2026-C2-connectingapp/issues/20)에서 추적합니다.

[2026년 10월 23일 UI 개편 내용](design/implementation/2026-10-23/README.md)은 선택한 발견·대화 시안과 추가 사진·관심사 요구사항을 기준으로 정리했습니다.

[Apple 로그인·채팅 연결 검증](design/implementation/2026-10-23-chat/README.md)에서 기존 홈 유지와 로그인 전 안내 화면, 자동 테스트 및 검증 범위를 확인할 수 있습니다.

이번 단계는 Firebase 프로젝트를 연결해 실제 1:1 대화를 확인하는 개발 버전입니다. App Store 공개 전에는 신고와 운영 대응, 계정 삭제와 Apple 토큰 해제, 요청 남용 방지를 보완해야 합니다. 푸시 알림은 후속 기능입니다. 프로필 사진 공유·공개 일기·그룹·사진 메시지는 포함하지 않습니다. 발견은 100개 단위로 불러온 후보 안에서 공통 관심사 순으로 정렬합니다.

App Store 제출 전에는 최종 개인정보 표시와 SDK 선언 검토, 실기기·iPad·가로 화면·VoiceOver 검증이 남아 있습니다. 출시 완료 상태가 아닙니다.

## 작업 규칙

[CONTRIBUTING.md](CONTRIBUTING.md)의 한글 커밋·태그·이슈 기반 브랜치 규칙을 사용합니다. 작업 브랜치는 최신 `develop`을 반영한 뒤 PR로 통합하고, `main`은 출시 전까지 변경하지 않습니다.
