import Foundation
import Observation

/// Flutter shared_preferences와 같은 저장소("flutter." 접두어 키)를 그대로 사용합니다.
/// 같은 번들 ID로 업데이트되므로 기존 사용자의 플랜·진도·북마크가 이어집니다.
enum Prefs {
    private static let d = UserDefaults.standard
    private static func k(_ key: String) -> String { "flutter." + key }

    static func string(_ key: String) -> String? { d.string(forKey: k(key)) }
    static func set(_ value: String?, _ key: String) { value == nil ? d.removeObject(forKey: k(key)) : d.set(value, forKey: k(key)) }
    static func int(_ key: String) -> Int? { (d.object(forKey: k(key)) as? NSNumber)?.intValue }
    static func set(_ value: Int, _ key: String) { d.set(value, forKey: k(key)) }
    static func double(_ key: String) -> Double? { (d.object(forKey: k(key)) as? NSNumber)?.doubleValue }
    static func set(_ value: Double, _ key: String) { d.set(value, forKey: k(key)) }
    static func bool(_ key: String) -> Bool? { (d.object(forKey: k(key)) as? NSNumber)?.boolValue }
    static func set(_ value: Bool, _ key: String) { d.set(value, forKey: k(key)) }
    static func remove(_ key: String) { d.removeObject(forKey: k(key)) }
    static func has(_ key: String) -> Bool { d.object(forKey: k(key)) != nil }

    static func json<T: Decodable>(_ key: String, as: T.Type) -> T? {
        guard let s = string(key), let data = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    static func setJSON<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(String(data: data, encoding: .utf8), key)
    }
}

struct CompletedEntry: Codable, Hashable {
    var completedAt: String
    var comment: String?
    var date: Date? { PlanDates.parse(completedAt) }
}

struct Bookmark: Codable, Hashable, Identifiable {
    var bookId: Int
    var bookName: String
    var chapter: Int
    var verse: Int
    var text: String
    var savedAt: String
    var id: String { "\(bookId)-\(chapter)-\(verse)" }
}

@Observable
final class PlanStore {
    static let personal = "personal"
    static func groupSource(_ id: String) -> String { "group:\(id)" }

    private(set) var activeSource: String = PlanStore.personal
    private(set) var plan: ReadingPlan?
    private(set) var completed: [Int: CompletedEntry] = [:]
    private(set) var bookmarks: [Bookmark] = []

    init() {
        migrateLegacyKeys()
        reload()
    }

    // MARK: Loading

    func reload() {
        activeSource = Prefs.string("active_plan_source") ?? Self.personal
        plan = Self.loadPlan(for: activeSource)
        let raw = Prefs.json("completed_\(activeSource)", as: [String: CompletedEntry].self) ?? [:]
        completed = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, v) } })
        bookmarks = (Prefs.json("bookmarks", as: [Bookmark].self) ?? []).sorted { $0.savedAt > $1.savedAt }
        #if DEBUG
        if Demo.on {
            plan = nil; completed = [:]
            let day = String(PlanDates.string(Date()).prefix(10))
            bookmarks = [(4, 31, "겨자씨 한 알과 같으니", "07:10"), (6, 50, "안심하라 내니 두려워하지 말라", "16:05"), (2, 5, "작은 자야 네 죄 사함을 받았느니라", "21:40"), (1, 11, "너는 내 사랑하는 아들이라 내가 너를 기뻐하노라", "12:30")]
                .map { Bookmark(bookId: 41, bookName: "마가복음", chapter: $0.0, verse: $0.1, text: $0.2, savedAt: "\(day)T\($0.3):00.000") }
        }
        #endif
    }

    static func loadPlan(for source: String) -> ReadingPlan? {
        Prefs.json("plan_\(source)", as: ReadingPlan.self)
    }

    var activeGroupId: String? {
        activeSource.hasPrefix("group:") ? String(activeSource.dropFirst(6)) : nil
    }

    // MARK: Derived

    /// 다음에 읽을 Day = 마지막으로 완료한 Day + 1 (기존 앱과 같은 규칙)
    var currentDay: Int {
        guard let plan else { return 1 }
        guard let last = completed.keys.max() else { return 1 }
        return min(max(last + 1, 1), max(plan.totalDays, 1))
    }

    var isFinished: Bool {
        guard let plan else { return false }
        return completed.count >= plan.totalDays && plan.totalDays > 0
    }

    var progress: Double {
        guard let plan, plan.totalDays > 0 else { return 0 }
        return min(Double(completed.count) / Double(plan.totalDays), 1)
    }

    /// 오늘 날짜에 완료한 기록이 있는지 (Day 번호가 아닌 실제 날짜 기준)
    var readToday: Bool { !entries(on: Date()).isEmpty }

    func entries(on date: Date) -> [(day: Int, entry: CompletedEntry)] {
        let cal = Calendar.current
        return completed.compactMap { day, e in
            guard let d = e.date, cal.isDate(d, inSameDayAs: date) else { return nil }
            return (day, e)
        }.sorted { $0.day < $1.day }
    }

    /// 날짜 기준 연속 읽기 (오늘 또는 어제까지 이어진 날 수)
    var streak: Int {
        let cal = Calendar.current
        let days = Set(completed.values.compactMap { $0.date.map { cal.startOfDay(for: $0) } })
        var cursor = cal.startOfDay(for: Date())
        if !days.contains(cursor) { cursor = cal.date(byAdding: .day, value: -1, to: cursor)! }
        var n = 0
        while days.contains(cursor) {
            n += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return n
    }

    var bestStreak: Int {
        let cal = Calendar.current
        let days = Set(completed.values.compactMap { $0.date.map { cal.startOfDay(for: $0) } }).sorted()
        var best = 0, run = 0
        var prev: Date?
        for d in days {
            if let p = prev, cal.dateComponents([.day], from: p, to: d).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run); prev = d
        }
        return max(best, Prefs.int("best_streak_\(activeSource)") ?? 0)
    }

    // MARK: Mutations

    func setActiveSource(_ source: String) {
        Prefs.set(source, "active_plan_source")
        reload()
    }

    func savePlan(_ plan: ReadingPlan, for source: String? = nil) {
        Prefs.setJSON(plan, "plan_\(source ?? activeSource)")
        if source == nil || source == activeSource { reload() }
    }

    /// 새 개인 플랜 시작 — 이전 개인 진도는 지우고 오늘을 Day 1로 시작합니다.
    func startPersonalPlan(_ plan: ReadingPlan) {
        Prefs.set(Self.personal, "active_plan_source")
        Prefs.remove("completed_\(Self.personal)")
        Prefs.set(0, "current_streak_\(Self.personal)")
        Prefs.setJSON(plan, "plan_\(Self.personal)")
        reload()
    }

    func clearActivePlan() {
        let src = activeSource
        Prefs.remove("plan_\(src)")
        Prefs.remove("completed_\(src)")
        Prefs.set(0, "current_streak_\(src)")
        Prefs.set(0, "best_streak_\(src)")
        if src != Self.personal { Prefs.set(Self.personal, "active_plan_source") }
        reload()
    }

    func clearGroupCache(_ groupId: String) {
        let src = Self.groupSource(groupId)
        for k in ["plan_", "completed_", "current_streak_", "best_streak_"] { Prefs.remove(k + src) }
        if activeSource == src { Prefs.set(Self.personal, "active_plan_source") }
        reload()
    }

    func markComplete(day: Int, comment: String) {
        var raw = Prefs.json("completed_\(activeSource)", as: [String: CompletedEntry].self) ?? [:]
        raw[String(day)] = CompletedEntry(completedAt: PlanDates.string(Date()), comment: comment)
        Prefs.setJSON(raw, "completed_\(activeSource)")
        reload()
        Prefs.set(streak, "current_streak_\(activeSource)")
        if streak > (Prefs.int("best_streak_\(activeSource)") ?? 0) { Prefs.set(streak, "best_streak_\(activeSource)") }
    }

    func isBookmarked(_ v: Verse) -> Bool { bookmarks.contains { $0.id == v.id } }

    func toggleBookmark(_ v: Verse, bookName: String) {
        var list = Prefs.json("bookmarks", as: [Bookmark].self) ?? []
        if let i = list.firstIndex(where: { $0.id == v.id }) {
            list.remove(at: i)
        } else {
            list.append(Bookmark(bookId: v.bookId, bookName: bookName, chapter: v.chapter, verse: v.number,
                                 text: v.text, savedAt: PlanDates.string(Date())))
        }
        Prefs.setJSON(list, "bookmarks")
        reload()
    }

    // MARK: Legacy migration (Flutter v1.0 키 → personal 네임스페이스)

    private func migrateLegacyKeys() {
        if Prefs.has("active_plan_source") || Prefs.has("plan_personal") || Prefs.has("completed_personal") { return }
        if let p = Prefs.string("current_plan") { Prefs.set(p, "plan_personal"); Prefs.remove("current_plan") }
        if let c = Prefs.string("completed_days") { Prefs.set(c, "completed_personal"); Prefs.remove("completed_days") }
        if let s = Prefs.int("current_streak") { Prefs.set(s, "current_streak_personal"); Prefs.remove("current_streak") }
        if let s = Prefs.int("best_streak") { Prefs.set(s, "best_streak_personal"); Prefs.remove("best_streak") }
        Prefs.set(Self.personal, "active_plan_source")
    }
}

/// 읽기 설정 (기존 키 유지)
@Observable
final class ReadingSettings {
    var fontSize: Double { didSet { Prefs.set(fontSize, "reading_font_size") } }
    var useSerif: Bool { didSet { Prefs.set(useSerif ? "GowunBatang" : "system", "reading_font_family") } }

    init() {
        fontSize = min(max(Prefs.double("reading_font_size") ?? 19, 14), 28)
        let fam = Prefs.string("reading_font_family")
        useSerif = fam == nil || fam == "GowunBatang" || fam == "NanumMyeongjo" || fam == "serif"
    }
}
