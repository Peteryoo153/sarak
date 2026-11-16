import Foundation

struct ChapterRef: Codable, Hashable {
    var bookId: Int
    var bookName: String
    var chapter: Int
}

struct DayPlan: Codable, Hashable, Identifiable {
    var dayNumber: Int
    var displayRange: String
    var estimatedMinutes: Int
    var chapters: [ChapterRef]
    var id: Int { dayNumber }

    static func range(for chapters: [ChapterRef]) -> String {
        guard let first = chapters.first, let last = chapters.last else { return "" }
        if first.bookId == last.bookId {
            return first.chapter == last.chapter
                ? "\(first.bookName) \(first.chapter)장"
                : "\(first.bookName) \(first.chapter)–\(last.chapter)장"
        }
        return "\(first.bookName) \(first.chapter)장 – \(last.bookName) \(last.chapter)장"
    }

    var shortRange: String { displayRange }
}

/// 로컬에 저장되는 플랜 (Flutter 버전과 같은 JSON 구조 → 기존 사용자 데이터 그대로 읽힘)
struct ReadingPlan: Codable, Hashable {
    var rangeName: String
    var startBookId: Int
    var endBookId: Int
    var totalDays: Int
    var minutesPerDay: Int
    var startDate: String
    var schedule: [DayPlan]
    var source: String?
    var groupId: String?
    var groupName: String?

    var start: Date { PlanDates.parse(startDate) ?? Date() }

    func day(_ n: Int) -> DayPlan? {
        guard !schedule.isEmpty else { return nil }
        return schedule[min(max(n - 1, 0), schedule.count - 1)]
    }

    /// 오늘 날짜 기준 계획상의 Day (시작일 = Day 1, 시간 무시)
    func scheduledDay(on date: Date = Date()) -> Int {
        let cal = Calendar.current
        let d = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: date)).day ?? 0
        return d + 1
    }
}

enum PlanDates {
    static func parse(_ s: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        f1.formatOptions = [.withInternetDateTime]
        if let d = f1.date(from: s) { return d }
        // Dart의 DateTime.toIso8601String() — 타임존 없는 로컬 시각 (예: 2026-03-01T09:12:33.123456)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    static func string(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return f.string(from: d)
    }
}

struct RangePreset: Identifiable, Hashable {
    let label: String
    let chapters: Int
    let startBookId: Int
    let endBookId: Int
    var id: String { label }

    static let all: [RangePreset] = [
        .init(label: "신구약 전체", chapters: 1189, startBookId: 1, endBookId: 66),
        .init(label: "구약", chapters: 929, startBookId: 1, endBookId: 39),
        .init(label: "신약", chapters: 260, startBookId: 40, endBookId: 66),
    ]

    static func matching(start: Int, end: Int) -> RangePreset {
        all.first { $0.startBookId == start && $0.endBookId == end } ?? all[0]
    }
}

enum ScheduleEngine {
    static let readingSpeed = 270 // 분당 글자 수

    /// 목표 기간(일)에 맞춰 장 단위로 균등 분배합니다.
    /// (기존 Flutter 엔진은 '분/일'로만 나눠서 목표 기간이 무시되던 문제를 고침)
    static func generate(startBookId: Int, endBookId: Int, totalDays: Int) -> [DayPlan] {
        let sizes = BibleDB.shared.chapterSizes(from: startBookId, to: endBookId)
        guard !sizes.isEmpty, totalDays > 0 else { return [] }
        let names = Dictionary(uniqueKeysWithValues: BibleDB.shared.books.map { ($0.id, $0.name) })
        let total = sizes.reduce(0) { $0 + $1.2 }
        let days = min(totalDays, sizes.count)
        let target = Double(total) / Double(days)

        var plans: [DayPlan] = []
        var current: [ChapterRef] = []
        var chars = 0
        var consumed = 0

        for (i, (book, chapter, size)) in sizes.enumerated() {
            current.append(ChapterRef(bookId: book, bookName: names[book] ?? "", chapter: chapter))
            chars += size
            consumed += size
            let remainingChapters = sizes.count - i - 1
            let remainingDays = days - plans.count - 1
            // 누적 목표선에 도달하면 하루 마감. 남은 장이 남은 날보다 적어지지 않도록 보장.
            let idealEnd = target * Double(plans.count + 1)
            let shouldClose = Double(consumed) >= idealEnd - Double(size) / 2 || remainingChapters <= remainingDays
            if remainingDays > 0 && shouldClose {
                plans.append(make(day: plans.count + 1, chapters: current, chars: chars))
                current = []; chars = 0
            }
        }
        if !current.isEmpty { plans.append(make(day: plans.count + 1, chapters: current, chars: chars)) }
        return plans
    }

    private static func make(day: Int, chapters: [ChapterRef], chars: Int) -> DayPlan {
        DayPlan(dayNumber: day, displayRange: DayPlan.range(for: chapters),
                estimatedMinutes: max(1, Int((Double(chars) / Double(readingSpeed)).rounded())), chapters: chapters)
    }

    static func estimatedMinutes(preset: RangePreset, days: Int) -> Int {
        let total = BibleDB.shared.chapterSizes(from: preset.startBookId, to: preset.endBookId).reduce(0) { $0 + $1.2 }
        return max(1, Int((Double(total) / Double(max(days, 1)) / Double(readingSpeed)).rounded()))
    }
}
