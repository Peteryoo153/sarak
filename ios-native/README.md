# 사락 (Sarak) — iOS 네이티브 앱 (SwiftUI)

Flutter 앱(`Peteryoo153/sarak`)을 iPhone 전용 SwiftUI로 다시 만든 버전입니다.
번들 ID(`com.chanhoyoo.sarak`)가 같아서 App Store에 **업데이트로** 올라가고, 기존 사용자의 플랜·진도·북마크를 그대로 이어받습니다.

- 디자인 시스템: https://claude.ai/artifact/H9vGde1Jvad4UHS9GfLd7g
- 화면 시안: https://claude.ai/artifact/4SuNb6SNnwXgW6QNW8Uokw

## 빌드

```bash
brew install xcodegen      # 이미 설치되어 있음
xcodegen generate          # project.yml → Sarak.xcodeproj
open Sarak.xcodeproj
```

- 최소 iOS 17, 버전 2.0.0 (10)
- 패키지: Firebase(Core/Auth/Firestore) 12.x, GoogleSignIn 9.x (Swift Package Manager)
- 글꼴: 고운바탕(GowunBatang, SIL OFL) — `Sarak/Resources/Fonts`

## 구조

| 폴더 | 내용 |
|---|---|
| `Sarak/App` | 앱 진입점, Info.plist, entitlements, 딥링크 처리 |
| `Sarak/Core/Theme.swift` | 디자인 토큰(라이트/다크 자동), 버튼·카드 컴포넌트 |
| `Sarak/Core/PlanStore.swift` | 플랜·진도·북마크 저장 (Flutter `flutter.*` 키 그대로 사용) |
| `Sarak/Core/Plan.swift` | 통독 플랜 생성 엔진 (목표 기간에 맞춰 균등 분배) |
| `Sarak/Core/BibleDB.swift` | 번들 `bible.db` (개역개정) 읽기 |
| `Sarak/Core/Session.swift` | 로그인(Apple/Google), 그룹, 출석부, 응원 |
| `Sarak/Core/Services.swift` | 매일 알림, 공유(말씀 카드·인스타 스토리·초대) |
| `Sarak/Features` | 화면: 스플래시, 오늘, 읽기, 완료/공유, 달력, 함께(그룹), 더보기 |
| `firebase/` | Firestore 규칙·인덱스, 초대 링크 안내 페이지(Hosting) |

## 출시 전에 꼭 할 일

1. **Firestore 규칙·인덱스 배포** (계정 삭제, 초대코드 참여, 응원 기능에 필요)
   ```bash
   cd firebase
   firebase deploy --only firestore:rules,firestore:indexes,hosting
   ```
   - 기존 앱(1.x) 사용자도 같은 DB를 쓰므로, 규칙 배포 후 1.x 앱의 '초대코드 참여'는 새 `invites` 컬렉션을 쓰지 않아 실패할 수 있습니다. 2.0 업데이트와 함께 배포하세요.
2. **초대 링크 페이지**: `https://sarak-821b2.web.app/join?code=XXXXXX` (위 hosting 배포로 생성)
3. **인스타그램 스토리 바로 올리기**(선택): Meta 개발자 앱 ID를 `AppLinks.facebookAppID`에 넣으면 스토리 편집 화면으로 바로 열립니다. 없으면 공유 시트로 보냅니다.
4. **푸시 알림으로 응원 보내기**(다음 단계): 지금은 앱 안 배너로 표시됩니다. 실제 푸시는 FCM + Cloud Functions + APNs 키가 필요합니다.
5. Xcode에서 Signing 팀(7VAL2U8BVL) 확인 → Archive → App Store Connect 업로드
