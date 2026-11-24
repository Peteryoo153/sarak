import Foundation
import Observation

/// 말씀길 진도. 기존 통독 플랜 저장소(PlanStore)와 따로 보관합니다.
@Observable
final class PathStore {
    private(set) var completed: [Int: CompletedEntry] = [:]
    var total: Int { WordPath.mark.days.count }

    init() { reload() }

    func reload() {
        let raw = Prefs.json("path_mark_completed", as: [String: CompletedEntry].self) ?? [:]
        completed = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, v) } })
        #if DEBUG
        if Demo.on { seedDemo() }
        #endif
    }

    var isFinished: Bool { completed.count >= total }
    var readToday: Bool { completed.values.contains { $0.date.map(Calendar.current.isDateInToday) ?? false } }
    /// 다음에 읽을 날
    var nextDay: Int { (1...total).first { completed[$0] == nil } ?? total }
    /// 오늘 화면에 보일 날. 오늘 읽었으면 읽은 그날에 머뭅니다.
    var today: WordPath.Day {
        if let d = completed.filter({ $0.value.date.map(Calendar.current.isDateInToday) ?? false }).keys.max() { return WordPath.mark.day(d) }
        return WordPath.mark.day(nextDay)
    }
    /// 이틀 이상 쉬었다 돌아온 경우
    var isBack: Bool {
        guard let last = completed.values.compactMap(\.date).max(), !readToday else { return false }
        return (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: Calendar.current.startOfDay(for: Date())).day ?? 0) >= 3
    }

    func complete(day: Int, note: String) {
        completed[day] = CompletedEntry(completedAt: PlanDates.string(Date()), comment: note)
        Prefs.setJSON(Dictionary(uniqueKeysWithValues: completed.map { (String($0.key), $0.value) }), "path_mark_completed")
    }
    /// 남긴 한 줄만 고치거나 지웁니다. 읽은 기록은 그대로 둡니다.
    func setNote(day: Int, _ note: String?) {
        guard completed[day] != nil else { return }
        completed[day]?.comment = note
        Prefs.setJSON(Dictionary(uniqueKeysWithValues: completed.map { (String($0.key), $0.value) }), "path_mark_completed")
    }
    func restart() {
        completed = [:]
        Prefs.remove("path_mark_completed")
    }

    #if DEBUG
    private func seedDemo() {
        for d in 1...5 {
            let date = Calendar.current.date(byAdding: .day, value: d - 6, to: Date())!
            completed[d] = CompletedEntry(completedAt: PlanDates.string(date), comment: d == 5 ? "작은 씨앗도 자라게 하시는 하나님" : nil)
        }
    }
    #endif
}
