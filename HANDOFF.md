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
- Apple Watch Series 11 46mm: 앱이 실행되고 네 시간 캡처. 긴 말씀 겹침은 수정함
- iPhone Duo: 펼침 가로(골방·말씀첩), 닫힘(골방)

### 확인하지 못한 것
- 워치와 아이폰 연결, 42mm·49mm 화면, 항상 표시
- 실제 알림 도착과 알림 동작 네 가지
- 듀오 펼침 세로와 반쯤 접힘, 접었다 펼 때 이어지는지
- 아이폰 가로, VoiceOver
- 로그인한 상태의 '함께' 화면, 실제 스토어 버전에서 업데이트
- Release 빌드와 업로드

## 남은 작업 (순서대로)

1. [x] **워치 수정**: 긴 말씀과 종이 끝이 겹치지 않게 고침(46mm 확인). 42mm·49mm는 미확인
2. [ ] **남은 점검**: 실기기에서 알림 도착과 동작 네 가지(시뮬레이터에서 예약 53개는 확인), 듀오 반쯤 접힘, 로그인한 함께 화면. 확인 끝: 가장 큰 글자, 옛 플랜 이어받기, 첫 실행
3. [x] **스크린샷 원본**: `design/screenshots-raw`
4. [x] **홍보 문구 스크린샷**: `design/screenshots-store`(아이폰 6, 아이패드 4, 듀오 4, 워치 3). 고치려면 `source/build.py` 뒤 `node shoot.mjs`
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
8. [x] **빌드 12 업로드**, App Store Connect에 3.0.0 생성·빌드 연결. 심사 제출은 안 함
9. [x] 스크린샷 23장·설명·업그레이드 문구·심사 메모 등록. [ ] TestFlight 실기기 확인, 연령 등급 질문, 감수·역본 허락 뒤 직접 심사 제출

### 시안에는 있고 앱에는 아직 없는 것
위젯, 펼친 알림의 종이 화면, 워치 컴플리케이션과 스마트 스택, '5분 더'와 10분 읽기(구약 본문 자료 없음), 사락 소리 파일, 시간 추가·요일 선택, 듀오 반쯤 접힘 듣기, 말씀첩의 '받은 말씀'
