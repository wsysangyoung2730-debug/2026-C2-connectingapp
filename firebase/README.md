# 날담 Firestore 권한 규칙

이 폴더는 실제 사용자 프로필·대화 요청·1:1 메시지의 권한 규칙과 로컬 에뮬레이터 검증을 담습니다. 실제 Firebase 프로젝트를 만들거나 배포하지 않아도 테스트할 수 있습니다.

## 테스트

Node.js 22 이상과 JDK 21 이상을 준비한 뒤 이 폴더에서 실행합니다.

```sh
npm ci
npm test
```

`demo-naldam-chat`이라는 가상 프로젝트와 `127.0.0.1:8080`의 Firestore 에뮬레이터만 사용합니다. 실제 서비스 데이터나 결제에는 접근하지 않습니다. 이미 에뮬레이터가 실행 중이면 `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run test:running-emulator`로 테스트만 실행할 수 있습니다.

macOS에서 Android Studio의 JBR을 사용하는 예:

```sh
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
PATH="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin:$PATH" npm test
```

## 저장 구조

| 경로 | 필드 | 접근 범위 |
| --- | --- | --- |
| `profiles/{uid}` | `name`, `interests`, `createdAt`, `updatedAt` | 로그인한 사용자가 읽고 본인만 수정 |
| `rooms/{roomID}` | `members`, `senderID`, `recipientID`, `status`, `createdAt`, `updatedAt` | 두 참여자만 읽기. 요청 작성자는 `pending`으로 생성, 수신자만 `active`로 수락 |
| `rooms/{roomID}/messages/{messageID}` | `senderID`, `body`, `createdAt` | 수락한 두 참여자만 읽기. 차단 관계가 없는 참여자만 작성, 수정·삭제 불가 |
| `rooms/{roomID}/states/{uid}` | 선택 필드 `lastReadAt`, `archived` | 본인인 참여자만 읽고 수정 |
| `users/{uid}/blocks/{otherUID}` | `createdAt` | 차단한 본인만 읽고 수정 |

익명 계정과 로그인하지 않은 요청은 모두 거부합니다. 알려지지 않은 컬렉션도 거부합니다. 개인 일기·초안·프로필 사진은 이 구조에 전송되지 않습니다.

- 앱은 두 UID를 정렬하고 `__`로 이어 방 ID를 만듭니다. 규칙도 정확히 두 명이며 UID가 사전 순서이고 ID가 members의 순서와 일치하는지 확인하여 같은 두 사람의 방을 중복 생성하지 못하게 합니다. UID 안의 `/` 및 `__`는 허용하지 않습니다.
- `pending → active`는 수신자만, `pending → declined`는 요청 취소 또는 거절을 위해 두 참여자 모두 가능합니다. 거절된 요청은 다시 열 수 없습니다.
- 양쪽 중 한 명이라도 상대를 차단하면 새 요청·수락·메시지 작성을 거부합니다. 기존 대화의 기록은 계속 읽을 수 있습니다.
- 메시지는 서버 시간으로 생성해야 합니다. 기기 시간으로 생성한 메시지와 다른 사람을 발신자로 지정한 메시지는 거부합니다.
- 재시도는 같은 메시지 ID를 사용하는 트랜잭션으로 처리합니다. 이미 서버에 저장된 메시지는 읽어서 확인하며 덮어쓰지 않습니다.
- 관심사는 6개 이하의 중복 없는 배열입니다. 앱은 이름 12글자·관심사 5글자를 사용자에게 보이는 문자(grapheme) 기준으로 제한합니다. 규칙은 같은 계산을 지원하지 않으므로 복합 이모지·결합 문자를 수용하는 방어적 상한(이름 1,024, 관심사 256 UTF-16 단위)을 검증합니다. 임의 클라이언트에 대해서도 정확한 grapheme 상한을 강제하려면 후속 서버 검증이 필요합니다.
- 메시지는 2,000 UTF-16 단위 이내이며 공백만 있는 본문은 허용하지 않습니다. 일반 한글·영문은 한 글자에 1단위, 일부 이모지는 2단위 이상을 차지합니다. 앱과 서버가 같은 상한을 사용합니다.

## 배포

Firebase 프로젝트에서 Firestore의 **프로덕션 모드** 데이터베이스를 만들고, 앱 설정을 마친 뒤 직접 배포합니다.

```sh
npx firebase-tools login
npx firebase-tools deploy --only firestore:rules,firestore:indexes --project YOUR_FIREBASE_PROJECT_ID
```

앱이 사용하는 방 목록 쿼리는 `members array-contains 현재 UID`, 메시지 쿼리는 방 내부 `createdAt` 정렬입니다. 현재 복합 인덱스는 필요하지 않습니다.

규칙 테스트는 두 계정의 요청·수락·실시간 메시지 왕복과 재조회, 위조·제삼자 접근·타임스탬프·차단·개인 상태 접근을 확인합니다. 실제 Apple 로그인, iOS SDK 통신과 서로 다른 두 iPhone에서의 최종 확인은 별도로 수행해야 합니다.

공식 참고: [권한 조건](https://firebase.google.com/docs/firestore/security/rules-conditions), [규칙 테스트](https://firebase.google.com/docs/rules/unit-tests), [에뮬레이터 설정](https://firebase.google.com/docs/emulator-suite/install_and_configure).
