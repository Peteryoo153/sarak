import WatchConnectivity

/// 오늘 몇 번째 날인지만 워치에 알려 줍니다.
final class PhoneLink: NSObject, WCSessionDelegate {
    static let shared = PhoneLink()
    private var pending: Int?
    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    func send(day: Int) {
        pending = day
        guard WCSession.isSupported(), WCSession.default.activationState == .activated, WCSession.default.isWatchAppInstalled else { return }
        try? WCSession.default.updateApplicationContext(["day": day, "date": String(PlanDates.string(Date()).prefix(10))])
    }
    func session(_ s: WCSession, activationDidCompleteWith st: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { if let d = self.pending { self.send(day: d) } }
    }
    func sessionDidBecomeInactive(_ s: WCSession) {}
    func sessionDidDeactivate(_ s: WCSession) { s.activate() }
}
