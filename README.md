# 날담

하루의 질문에 답하며 나를 기록하고, 관심사와 이야기를 통해 연결되는 iOS 앱입니다. C2 프로젝트를 PAPER 디자인으로 개편했습니다. 개인 기록과 관심사 저장은 실제로 동작하며, 발견과 대화는 **서버에 연결되지 않은 로컬 샘플 체험**입니다.

## 구현한 화면

- **홈**: 오늘의 질문, 저장·이어쓰기 상태, 실제 주간 기록 현황, 기록 모음 이동, 프로필 편집
- **봉투 풀업**: 접힘·중간·펼침의 3단계, 관심사 검색과 최대 6개 선택, 명시적 저장과 취소
- **기록**: 날짜별 작성·수정·삭제, 임시 저장, 달력, 내용 검색, 원래 질문 보존
- **발견**: 저장한 관심사와 공통점이 많은 샘플 프로필 정렬, 필터와 이야기 상세
- **대화**: 샘플 요청·수락·거절, 메시지와 초안 저장, 차단·해제, 대화 보관과 복원
- **브랜드**: 날담 PAPER 로고와 앱 아이콘, 아이보리 종이 화면, 네이티브 Liquid Glass 탭

메인 메뉴는 홈·발견·대화입니다. 개인 기록은 발견이나 대화에 자동으로 공유되지 않습니다. 질문은 현재 7개의 질문을 날짜별로 순환하며, 이미 저장한 기록은 당시 질문을 유지합니다.

## 실행

Xcode에서 `C2_connecting app.xcodeproj`를 열고 공유 스킴 `C2_connecting app`을 선택합니다. 현재 최소 버전은 기존 설정과 동일한 iOS 26.2이며, 검증에 사용한 환경은 Xcode 26.5와 iOS 26.5 시뮬레이터입니다. 시뮬레이터 실행에는 별도 서버 키가 필요하지 않습니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'C2_connecting app.xcodeproj' -scheme 'C2_connecting app' \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/naldam-build CODE_SIGNING_ALLOWED=NO build
```

실기기 실행은 Xcode에서 본인의 서명 팀을 설정합니다. 앱 표시 이름만 날담으로 바꿨으며, 기존 설치의 저장소 연속성을 위해 번들 식별자는 유지했습니다.

## 데이터 보관

기록과 관심사는 SwiftData, 샘플 대화는 앱 전용 Application Support 아래의 JSON 파일, 프로필 이름과 온보딩 여부는 UserDefaults에 저장합니다. 기존 `QuizEntry`와 `InterestSelection` 모델을 유지하고 `JournalDraft`를 추가했습니다. 저장소 초기화나 기존 기록 일괄 삭제는 하지 않습니다.

메시지 저장 성공은 기기 내 저장을 뜻하며 실제 발송·서버 읽음·푸시 알림은 제공하지 않습니다. 손상된 대화 파일은 자동으로 덮어쓰지 않습니다. 계정 동기화·내보내기·복원 기능은 아직 없으므로 앱 삭제 시 데이터가 사라질 수 있습니다.

## 테스트

공유 스킴에 `NaldamTests`와 `NaldamUITests`가 연결되어 있습니다. Xcode의 Test 동작으로 실행하거나 설치된 시뮬레이터 이름을 지정합니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'C2_connecting app.xcodeproj' -scheme 'C2_connecting app' \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/naldam-build CODE_SIGNING_ALLOWED=NO test
```

단위 테스트는 달력 경계·날짜별 저장·질문 보존·삭제 범위·저장소 마이그레이션과 재개방·샘플 대화 상태·파일 오류를 확인합니다. UI 테스트는 기록 저장과 홈 반영, 기록함 이동, 봉투 편집, 발견과 샘플 대화, 온보딩과 큰 글자 화면을 확인합니다.

UI 테스트는 Debug 전용 인자를 사용해 메모리 기록 저장소와 별도의 임시 대화 파일로 실행합니다. 사용자의 일반 기록 저장소를 초기화하지 않습니다.

2026년 10월 3일 iPhone 17 Pro 시뮬레이터에서 단위 테스트 20개와 UI 테스트 4개가 모두 통과했습니다. [실제 구현 화면과 검증 범위](design/implementation/2026-10-03/README.md)를 함께 보관했습니다.

## 코드 구성

| 위치 | 역할 |
| --- | --- |
| `App` | 앱 진입, 디자인 공통 요소, 탭, 프로필 |
| `Main` | 질문 카드와 실제 기록 기반 홈 |
| `Quiz` | 기록 모델, 저장 처리, 편집과 달력 |
| `Interests` | 봉투 형태, 풀업 상태, 관심사 편집 |
| `Social` | 샘플 프로필, 로컬 대화 저장소와 화면 |
| `Tests`, `UITests` | 데이터·UI 회귀 테스트 |
| `design` | 브랜드·UI 시안과 실제 구현 캡처 |

기존 C2 일부 컴포넌트는 참고용으로 남아 있으나 새 진입 흐름에서는 사용하지 않습니다. 앱 아이콘은 `scripts/render-app-icon.swift`의 원본 벡터 경로로 재생성할 수 있습니다.

## 다음 출시 작업

실제 연결 서비스를 출시하려면 서버·로그인 방식부터 정해야 합니다. 이후 실제 사용자 프로필과 공개 이야기의 동의 범위, 메시지 전달, 서버 권한 검사, 신고·차단 운영, 계정 삭제, 데이터 동기화·복원, 알림을 구현해야 합니다. 현재 샘플 수락 버튼은 실제 상대의 동의를 대체하지 않습니다.

App Store 제출 전에는 개인정보 및 사용 API 선언, 실기기·iPad·가로 화면·VoiceOver 검증, 질문 콘텐츠 확장, 네이밍 사용 가능 여부 확인이 남아 있습니다. 현재 단계는 로컬 기능과 UI 통합 완료를 목표로 한 개발 버전이며 출시 완료 상태가 아닙니다.

## 작업 규칙

[CONTRIBUTING.md](CONTRIBUTING.md)의 한글 커밋·태그·이슈 기반 브랜치 규칙을 사용합니다. 작업 브랜치는 최신 `develop`을 반영한 뒤 PR로 통합하고, `main`은 출시 전까지 변경하지 않습니다.
