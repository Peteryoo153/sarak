import SwiftUI
import FirebaseCore
import GoogleSignIn
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        WordAlerts.registerCategory()
        PhoneLink.shared.start()
        return true
    }
    func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive r: UNNotificationResponse) async { await WordAlerts.handle(r) }
    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .list, .sound] }
}

@main
struct SarakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = PlanStore()
    @State private var session = Session()
    @State private var settings = ReadingSettings()
    @State private var path = PathStore()
    @AppStorage("welcomed3") private var welcomed = false
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if welcomed || skipIntro { MainTabView() } else { WelcomeView { welcomed = true } }
                }
                .opacity(showSplash && !skipIntro ? 0 : 1)
                if showSplash && !skipIntro {
                    SplashView { withAnimation(.easeInOut(duration: 0.45)) { showSplash = false } }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environment(store)
            .environment(session)
            .environment(settings)
            .environment(path)
            .preferredColorScheme(appearance.colorScheme)
            .tint(Ink.primary)
            .onOpenURL { url in
                if GIDSignIn.sharedInstance.handle(url) { return }
                handleDeepLink(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { handleDeepLink(url) }
            }
        }
    }

    private var skipIntro: Bool {
        #if DEBUG
        return Demo.on && Demo.screen != "welcome"
        #else
        return false
        #endif
    }

    /// sarak://join?code=ABC123  또는  https://sarak-821b2.web.app/join?code=ABC123
    private func handleDeepLink(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let isJoin = url.host == "join" || comps.path.hasSuffix("/join")
        if isJoin, let code = comps.queryItems?.first(where: { $0.name == "code" })?.value {
            session.pendingInviteCode = code.uppercased()
        }
    }
}
