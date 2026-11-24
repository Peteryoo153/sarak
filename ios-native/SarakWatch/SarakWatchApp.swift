import SwiftUI
import WatchConnectivity
import Observation

/// 아이폰에서 '오늘 몇 번째 날'만 받아 옵니다. 말씀은 워치 안에 있습니다.
@Observable
final class WatchModel: NSObject, WCSessionDelegate {
    private(set) var day = 1
    private(set) var hour = SarakHour.now
    override init() {
        super.init()
        let d = UserDefaults.standard
        if d.integer(forKey: "day") > 0 { day = d.integer(forKey: "day") }
        #if DEBUG
        if let n = Demo.env["SARAK_DAY"].flatMap(Int.init) { day = n }
        #endif
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }
    func refresh() { hour = .now }
    private func take(_ c: [String: Any]) {
        guard let n = c["day"] as? Int else { return }
        DispatchQueue.main.async { self.day = n; UserDefaults.standard.set(n, forKey: "day") }
    }
    func session(_ s: WCSession, activationDidCompleteWith st: WCSessionActivationState, error: Error?) { take(s.receivedApplicationContext) }
    func session(_ s: WCSession, didReceiveApplicationContext c: [String: Any]) { take(c) }
}

@main
struct SarakWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            let a = WordPath.mark.day(model.day).alert(model.hour)
            WatchVerse(hour: model.hour, verse: a.text, source: a.reference, next: nextText)
                .onChange(of: phase) { _, p in if p == .active { model.refresh() } }
        }
    }
    private var nextText: String {
        switch model.hour {
        case .morning: "다음 말씀은 한낮에"
        case .noon: "다음 말씀은 쉼의 때에"
        case .rest: "다음 말씀은 밤에"
        case .night: "다음 말씀은 아침에"
        }
    }
}
