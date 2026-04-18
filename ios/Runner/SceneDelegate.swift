import Flutter
import UIKit
import GoogleSignIn

class SceneDelegate: FlutterSceneDelegate {
  // iOS 13+ SceneDelegate 환경에서는 URL 콜백이 AppDelegate가 아닌 이쪽으로 전달됩니다.
  // 구글 로그인(리다이렉트 URL scheme)을 GIDSignIn에 넘겨줘야 로그인 완료가 됩니다.
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for urlContext in URLContexts {
      _ = GIDSignIn.sharedInstance.handle(urlContext.url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
