import Foundation
import Observation

/// 한 번에 읽는 본문
struct Reading: Identifiable, Hashable {
    enum Kind: Hashable { case path(Int), plan(DayPlan), free }
    struct Segment: Hashable { let bookId: Int, bookName: String, chapter: Int; var from = 1; var to = 999 }
    let title: String
    let minutes: Int?
    let segments: [Segment]
    let kind: Kind
    var id: String { title }

    static func path(_ d: WordPath.Day) -> Reading {
        let (f, t) = (d.from, d.to)
        let segs = (f.chapter...t.chapter).map {
            Segment(bookId: 41, bookName: "마가복음", chapter: $0, from: $0 == f.chapter ? f.verse : 1, to: $0 == t.chapter ? t.verse : 999)
        }
        let end = f.chapter == t.chapter ? "\(t.verse)" : d.end
        return Reading(title: "마가복음 \(d.start)–\(end)", minutes: Int(d.minutes.rounded()), segments: segs, kind: .path(d.day))
    }
    /// 통독 플랜을 쓰던 분은 그 플랜을, 아니면 말씀길을 읽습니다.
    static func today(_ store: PlanStore, _ path: PathStore) -> Reading {
        if let plan = store.plan, !store.isFinished, let d = plan.day(store.currentDay) { return .plan(d) }
        return .path(path.today)
    }
    static func plan(_ d: DayPlan) -> Reading {
        Reading(title: d.displayRange, minutes: d.estimatedMinutes,
                segments: d.chapters.map { Segment(bookId: $0.bookId, bookName: $0.bookName, chapter: $0.chapter) }, kind: .plan(d))
    }
    static func chapter(_ b: Book, _ c: Int) -> Reading {
        Reading(title: "\(b.name) \(c)장", minutes: nil, segments: [Segment(bookId: b.id, bookName: b.name, chapter: c)], kind: .free)
    }
}

/// 접고 펴도 이어지도록 선택과 위치를 화면 밖에서 들고 있습니다.
@Observable
final class ReaderModel {
    struct Block: Identifiable { let id: Int; let segment: Reading.Segment; let verses: [Verse]; let startsChapter: Bool }
    private(set) var reading: Reading
    private(set) var blocks: [Block] = []
    var selected: Set<String> = []
    var position: Int?
    var finishing = false

    init(_ r: Reading) { reading = r; load() }

    func show(_ r: Reading) {
        guard r != reading else { return }
        reading = r; selected = []; position = nil; load()
    }
    private func load() {
        var out: [Block] = []
        for s in reading.segments {
            let v = BibleDB.shared.chapter(bookId: s.bookId, chapter: s.chapter).filter { $0.number >= s.from && $0.number <= s.to }
            for (i, start) in stride(from: 0, to: v.count, by: 6).enumerated() {
                out.append(Block(id: out.count, segment: s, verses: Array(v[start..<min(start + 6, v.count)]), startsChapter: i == 0))
            }
        }
        blocks = out
    }
    func toggle(_ id: String) { if selected.remove(id) == nil { selected.insert(id) } }
    var selectedVerses: [Verse] { blocks.flatMap(\.verses).filter { selected.contains($0.id) } }
    func bookName(_ v: Verse) -> String { reading.segments.first { $0.bookId == v.bookId }?.bookName ?? "" }
}
