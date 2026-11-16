import Foundation
import SQLite3

struct Verse: Identifiable, Hashable {
    let bookId: Int
    let chapter: Int
    let number: Int
    let text: String
    var id: String { "\(bookId)-\(chapter)-\(number)" }
}

struct Book: Identifiable, Hashable {
    let id: Int
    let name: String
    let chapterCount: Int
}

/// 앱 번들의 bible.db(개역개정)를 읽기 전용으로 엽니다.
final class BibleDB {
    static let shared = BibleDB()
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "sarak.bibledb")

    private init() {
        guard let path = Bundle.main.path(forResource: "bible", ofType: "db") else {
            assertionFailure("bible.db missing from bundle")
            return
        }
        let uri = "file:\(path)?immutable=1"
        if sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) != SQLITE_OK {
            db = nil
        }
    }

    private func query<T>(_ sql: String, bind: [Int] = [], row: (OpaquePointer) -> T) -> [T] {
        queue.sync {
            guard let db else { return [] }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
            defer { sqlite3_finalize(stmt) }
            for (i, v) in bind.enumerated() { sqlite3_bind_int(stmt, Int32(i + 1), Int32(v)) }
            var out: [T] = []
            while sqlite3_step(stmt) == SQLITE_ROW { out.append(row(stmt)) }
            return out
        }
    }

    private static func text(_ s: OpaquePointer, _ i: Int32) -> String {
        sqlite3_column_text(s, i).map { String(cString: $0) } ?? ""
    }

    func chapter(bookId: Int, chapter: Int) -> [Verse] {
        query("SELECT verse, text FROM verses WHERE book_id = ? AND chapter = ? ORDER BY verse", bind: [bookId, chapter]) {
            Verse(bookId: bookId, chapter: chapter, number: Int(sqlite3_column_int($0, 0)), text: Self.text($0, 1))
        }
    }

    lazy var books: [Book] = query("SELECT id, name, total_chapters FROM books ORDER BY id") {
        Book(id: Int(sqlite3_column_int($0, 0)), name: Self.text($0, 1), chapterCount: Int(sqlite3_column_int($0, 2)))
    }

    func bookName(_ id: Int) -> String { books.first { $0.id == id }?.name ?? "" }

    /// (bookId, chapter, 글자 수) — 범위 내 모든 장
    func chapterSizes(from startBook: Int, to endBook: Int) -> [(Int, Int, Int)] {
        query("""
            SELECT book_id, chapter, SUM(char_count) FROM verses
            WHERE book_id >= ? AND book_id <= ?
            GROUP BY book_id, chapter ORDER BY book_id, chapter
            """, bind: [startBook, endBook]) {
            (Int(sqlite3_column_int($0, 0)), Int(sqlite3_column_int($0, 1)), Int(sqlite3_column_int($0, 2)))
        }
    }
}
