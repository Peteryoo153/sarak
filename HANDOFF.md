# 사락 3.0 인수인계 (2026-11-24)

맥미니에서 이어서 작업하기 위한 문서입니다. 브랜치는 `feat/sarak-3-design`입니다. `feat/swiftui-rewrite`(2.0.0, 빌드 11) 위에 쌓았습니다.

## 맥미니에서 시작하기

```bash
git clone https://github.com/Peteryoo153/sarak.git
cd sarak
git switch feat/sarak-3-design
brew install xcodegen
cd ios-native && xcodegen generate && open Sarak.xcodeproj
```

- Xcode 27.1에서 빌드했습니다. watchOS 27 플랫폼이 필요합니다: `xcodebuild -downloadPlatform watchOS`(약 3.8GB)
- 서명 팀 7VAL2U8BVL. 맥미니의 Xcode에 Apple 계정으로 로그인해야 합니다. 인증서는 저장소에 없습니다.
- 디스크 여유 20GB 이상을 권합니다.
- Claude Code로 이어가려면 이 폴더를 열고 "HANDOFF.md를 읽고 남은 작업을 이어서 해 줘"라고 하면 됩니다.

## 방향: 빛이 물든 종이 한 장

아침 살구, 한낮 버터, 쉼 세이지, 밤 라일락. 종이 끝이 들리고 아래로 다음 시간의 색이 비칩니다. 시안은 `design/sarak-3/사락-디자인셋.html`, 지킬 규칙은 그 폴더의 README에 있습니다. 원래 기획은 `content/사락-3.0-클로드디자인-프롬프트.md`이며, 그 안의 다섯 색 테마·로고 세 안·인물 일러스트는 새 방향으로 대체했습니다.

## 한 일

| 파일 (`ios-native/`) | 내용 |
|---|---|
| `Sarak/Core/SarakDesign.swift` | 색, 종이, 말씀 글자, 버튼, 골방 배치(한 장 / 펼친 책), 워치 화면 |
| `Sarak/Core/WordPath.swift`, `PathStore.swift`, `Resources/mark-25.json` | 마가복음 25일 말씀길과 진도 |
| `Sarak/Core/WordAlerts.swift`, `Features/WordAlertsView.swift` | 하루 네 번 알림, 첫 실행, 알림 설정 |
| `Sarak/Core/Reading.swift`, `Features/ReadingView.swift` | 본문 읽기, 절 선택, 듣기, 마침 |
| `Sarak/Features/RoomView.swift`, `BibleView.swift`, `KeepView.swift` | 골방, 성경(찾기 포함), 말씀첩과 달력 |
| `Sarak/Core/Theme.swift` | 예전 화면의 색을 새 색으로 연결 |
| `SarakWatch/`, `Sarak/Core/PhoneLink.swift` | 애플워치 앱 |
| `project.yml`, `Info.plist` | 3.0.0 (12), 워치 타깃, 전체 화면 고정 해제(듀오·아이패드 분할), 아이폰 가로 허용 |

기존 사용자의 통독 플랜·진도·북마크·그룹은 유지합니다. 플랜이 있으면 골방에서 그 플랜의 오늘 본문을 펼칩니다. 홈·달력 화면은 새 구조로 대체해 삭제했고, 연속 기록과 순위 표시는 없앴습니다. 서버에 올리는 연속 일수 값은 1.x 호환을 위해 그대로 보냅니다.

### 확인한 것
- 디버그 빌드 성공(시뮬레이터, 워치 앱 포함)
- iPhone 18 Pro Max: 화면 12종과 다크 골방 실행, 절 선택과 마치기 저장 확인
- iPad Pro 13: 세로와 가로(펼친 책)
- iPhone Duo: 펼침 가로(골방·말씀첩), 닫힘(골방)

### 확인하지 못한 것
- 애플워치 앱 실행, 워치와 아이폰 연결
- 실제 알림 수신과 알림 동작 네 가지
- 듀오 펼침 세로와 반쯤 접힘, 접었다 펼 때 이어지는지
- 아이폰 가로, 가장 큰 글자, VoiceOver
- 로그인한 상태의 '함께' 화면과 옛 버전에서 업데이트
- Release 빌드와 업로드

## 남은 작업 (순서대로)

1. [ ] **워치 확인**: Series 11 46mm(416×496), Ultra 3 49mm(422×514) 시뮬레이터에서 실행. 종이 끝과 글자가 겹치지 않는지 확인
2. [ ] **위의 '확인하지 못한 것' 점검**과 수정
3. [ ] **스크린샷 원본 보충**: 듀오 닫힘 읽기·쉼, 워치 네 시간. 있는 것은 `design/screenshots-raw`, 캡처는 `ios-native/scripts/cap.sh`
4. [ ] **홍보 문구 스크린샷 제작**: 아이폰 6.9형 1320×2868, 아이패드 13형 2064×2752, 워치 416×496 또는 422×514. 듀오 규격은 App Store Connect에서 확인. 파스텔 바탕, 고운바탕 문구, 아래에 실제 앱 화면
   - 오늘의 말씀이 찾아옵니다 (골방 아침)
   - 하루 네 번, 사락 (네 시간)
   - 하루 5분, 25일이면 마가복음 한 권 (읽기)
   - 마음에 머문 말씀을 품어 두세요 (말씀첩)
   - 오늘의 종이 한 장이 넘어갑니다 (마침)
   - 펼치면, 한 권의 책 (듀오·아이패드)
   - 손목 위에 놓인 한 구절 (워치)
5. [ ] **말씀 감수**: `content/마가복음-25일-감수표.md`가 아직 '초안 · 감수 전'
6. [ ] **역본 사용 허락**: 개역개정은 대한성서공회 확인 필요
7. [ ] **Firestore 규칙·인덱스·호스팅 배포**: `ios-native/README.md`의 출시 전 할 일
8. [ ] **Archive 후 App Store Connect에 빌드 업로드**. 심사 제출은 하지 않음. 워치 번들 ID `com.chanhoyoo.sarak.watchkitapp` 등록 필요
9. [ ] 스토어 설명·새로운 기능 문구 작성, 스크린샷 등록

### 시안에는 있고 앱에는 아직 없는 것
위젯, 펼친 알림의 종이 화면, 워치 컴플리케이션과 스마트 스택, '5분 더'와 10분 읽기(구약 본문 자료 없음), 사락 소리 파일, 시간 추가·요일 선택, 듀오 반쯤 접힘 듣기, 말씀첩의 '받은 말씀'
