import Foundation
import Observation

/// 말씀길: 하루 본문 하나와 네 번 찾아오는 말씀 (mark-25.json)
struct WordPath: Decodable {
    struct Alert: Decodable, Hashable {
        let slot: String, book: String, chapter: Int, verse: Int, text: String
        var reference: String { "\(book) \(chapter):\(verse)" }
        var hour: SarakHour { SarakHour.allCases.first { $0.name == slot } ?? .morning }
    }
    struct Day: Decodable, Hashable, Identifiable {
        let day: Int, title: String, start: String, end: String, minutes: Double, alerts: [Alert]
        var id: Int { day }
        func alert(_ h: SarakHour) -> Alert { alerts.first { $0.hour == h } ?? alerts[0] }
        private func parts(_ s: String) -> (Int, Int) { let a = s.split(separator: ":").compactMap { Int($0) }; return (a[0], a[1]) }
        var from: (chapter: Int, verse: Int) { parts(start) }
        var to: (chapter: Int, verse: Int) { parts(end) }
    }
    let book: String
    let days: [Day]

    static let mark: WordPath = {
        guard let u = Bundle.main.url(forResource: "mark-25", withExtension: "json"), let d = try? Data(contentsOf: u),
              let p = try? JSONDecoder().decode(WordPath.self, from: d) else { fatalError("mark-25.json") }
        return p
    }()
    func day(_ n: Int) -> Day { days[min(max(n, 1), days.count) - 1] }
}

extension SarakHour {
    static var now: SarakHour {
        #if DEBUG
        if let h = Demo.hour { return h }
        #endif
        return at(Date())
    }
    static func at(_ d: Date) -> SarakHour {
        switch Calendar.current.component(.hour, from: d) {
        case 4..<11: return .morning
        case 11..<15: return .noon
        case 15..<20: return .rest
        default: return .night
        }
    }
    var greeting: String {
        switch self { case .morning: "좋은 아침이에요"; case .noon: "잠시 숨을 골라요"; case .rest: "쉬어 가도 괜찮아요"; case .night: "오늘 하루, 수고했어요" }
    }
    var alertTitle: String {
        switch self { case .morning: "아침을 여는 말씀"; case .noon: "한낮의 말씀"; case .rest: "쉼의 말씀"; case .night: "하루를 덮는 말씀" }
    }
}

extension String {
    /// 큰 글자로 보일 말씀을 어절 단위로 나눕니다. 글자는 바꾸지 않습니다.
    func versed(_ width: Int) -> String {
        var lines: [String] = [], cur = ""
        for w in split(separator: " ").map(String.init) {
            if !cur.isEmpty, cur.count + 1 + w.count > width { lines.append(cur); cur = w } else { cur = cur.isEmpty ? w : cur + " " + w }
        }
        if !cur.isEmpty { lines.append(cur) }
        // 마지막 줄에 짧은 어절 하나만 남으면 윗줄의 끝 어절을 내립니다
        if lines.count > 1, let last = lines.last, !last.contains(" "), last.count <= 3, let cut = lines[lines.count - 2].lastIndex(of: " ") {
            let prev = lines[lines.count - 2]
            lines[lines.count - 2] = String(prev[..<cut])
            lines[lines.count - 1] = String(prev[prev.index(after: cut)...]) + " " + last
        }
        return lines.joined(separator: "\n")
    }
}

#if DEBUG
/// 화면 확인·스크린샷용 (디버그 빌드에만 있음): SARAK_HOUR, SARAK_DAY, SARAK_SCREEN 환경 변수
enum Demo {
    static let env = ProcessInfo.processInfo.environment
    static var on: Bool { env["SARAK_SCREEN"] != nil }
    static var screen: String { env["SARAK_SCREEN"] ?? "" }
    static var hour: SarakHour? { env["SARAK_HOUR"].flatMap(SarakHour.init) }
}
#endif
