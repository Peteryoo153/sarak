import SwiftUI
import FirebaseCore
import GoogleSignIn

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct SarakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = PlanStore()
    @State private var session = Session()
    @State private var settings = ReadingSettings()
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .opacity(showSplash ? 0 : 1)
                if showSplash {
                    SplashView { withAnimation(.easeInOut(duration: 0.45)) { showSplash = false } }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environment(store)
            .environment(session)
            .environment(settings)
            .preferredColorScheme(appearance.colorScheme)
            .tint(SarakColor.mintInk)
            .onOpenURL { url in
                if GIDSignIn.sharedInstance.handle(url) { return }
                handleDeepLink(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { handleDeepLink(url) }
            }
        }
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
