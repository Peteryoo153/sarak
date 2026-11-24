import Foundation
import UserNotifications

/// 하루 네 번 찾아가는 말씀 알림
enum WordAlerts {
    struct Slot: Codable, Identifiable, Equatable {
        var hour: SarakHour, on: Bool, h: Int, m: Int
        var id: String { hour.rawValue }
        static let defaults: [Slot] = [.init(hour: .morning, on: true, h: 7, m: 0), .init(hour: .noon, on: true, h: 12, m: 20),
                                       .init(hour: .rest, on: true, h: 16, m: 0), .init(hour: .night, on: true, h: 21, m: 30)]
    }
    struct Settings: Codable, Equatable {
        var enabled = false, showVerse = true, slots = Slot.defaults
        var skipDate: String?
    }

    static let category = "sarak.verse"
    private static let prefix = "sarak.word."

    static func load() -> Settings {
        if let s = Prefs.json("word_alerts", as: Settings.self) { return s }
        // 예전 '매일 읽기 알림' 시간을 아침 자리로 이어받습니다
        var s = Settings()
        let d = UserDefaults.standard
        if d.bool(forKey: "reminderEnabled") {
            s.slots[0].h = d.object(forKey: "reminderHour") as? Int ?? 7
            s.slots[0].m = d.object(forKey: "reminderMinute") as? Int ?? 0
        }
        return s
    }
    static func save(_ s: Settings) { Prefs.setJSON(s, "word_alerts") }

    static func registerCategory() {
        let c = UNNotificationCategory(identifier: category, actions: [
            UNNotificationAction(identifier: "keep", title: "마음에 품기"),
            UNNotificationAction(identifier: "amen", title: "아멘"),
            UNTextInputNotificationAction(identifier: "note", title: "한 줄 남기기", options: [], textInputButtonTitle: "남기기", textInputPlaceholder: "감사나 묵상 한 줄"),
            UNNotificationAction(identifier: "later", title: "한 시간 뒤"),
        ], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "말씀이 찾아왔어요", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([c])
    }

    static func request() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func dayKey(_ d: Date) -> String { String(PlanDates.string(d).prefix(10)) }

    /// 앞으로 두 주 치를 예약합니다 (iOS 한도 64개 안).
    static func reschedule(_ s: Settings, from day: Int, readToday: Bool) async {
        let center = UNUserNotificationCenter.current()
        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) && !$0.hasPrefix(prefix + "later") }
        center.removePendingNotificationRequests(withIdentifiers: old)
        guard s.enabled else { return }
        center.removePendingNotificationRequests(withIdentifiers: [ReminderService.id])
        let cal = Calendar.current, now = Date()
        for offset in 0..<14 {
            let date = cal.date(byAdding: .day, value: offset, to: now)!
            if s.skipDate == dayKey(date) { continue }
            let n = (day - 1 + offset) % WordPath.mark.days.count + 1
            let plan = WordPath.mark.day(n)
            for slot in s.slots where slot.on {
                var c = cal.dateComponents([.year, .month, .day], from: date)
                c.hour = slot.h; c.minute = slot.m
                guard let fire = cal.date(from: c), fire > now else { continue }
                try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(dayKey(date)).\(slot.id)",
                    content: content(plan.alert(slot.hour), slot: slot.hour, showVerse: s.showVerse),
                    trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false)))
            }
        }
    }

    static func content(_ a: WordPath.Alert, slot: SarakHour, showVerse: Bool) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = showVerse ? slot.alertTitle : "사락"
        c.body = showVerse ? "\(a.text)\n\(a.reference)" : "말씀이 찾아왔어요"
        c.categoryIdentifier = category
        c.sound = slot == .morning ? .default : nil
        c.userInfo = ["chapter": a.chapter, "verse": a.verse, "text": a.text, "book": a.book]
        return c
    }

    static func handle(_ r: UNNotificationResponse) async {
        let info = r.notification.request.content.userInfo
        guard let ch = info["chapter"] as? Int, let v = info["verse"] as? Int, let t = info["text"] as? String, let b = info["book"] as? String else { return }
        switch r.actionIdentifier {
        case "keep": addBookmark(chapter: ch, verse: v, text: t, book: b)
        case "note":
            if let n = (r as? UNTextInputNotificationResponse)?.userText, !n.isEmpty {
                var list = Prefs.json("word_notes", as: [WordNote].self) ?? []
                list.append(WordNote(text: n, reference: "\(b) \(ch):\(v)", savedAt: PlanDates.string(Date())))
                Prefs.setJSON(list, "word_notes")
            }
        case "later":
            let c = r.notification.request.content.mutableCopy() as! UNMutableNotificationContent
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: prefix + "later." + UUID().uuidString, content: c,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)))
        default: break
        }
    }

    static func addBookmark(chapter: Int, verse: Int, text: String, book: String) {
        var list = Prefs.json("bookmarks", as: [Bookmark].self) ?? []
        guard !list.contains(where: { $0.bookId == 41 && $0.chapter == chapter && $0.verse == verse }) else { return }
        list.append(Bookmark(bookId: 41, bookName: book, chapter: chapter, verse: verse, text: text, savedAt: PlanDates.string(Date())))
        Prefs.setJSON(list, "bookmarks")
    }
}

struct WordNote: Codable, Identifiable, Hashable {
    var text: String, reference: String, savedAt: String
    var id: String { savedAt + reference }
}
