import SwiftUI

/// 말씀첩: 품은 말씀, 남긴 한 줄, 달력
struct KeepView: View {
    @Environment(PlanStore.self) private var store
    @Environment(PathStore.self) private var path
    @Environment(\.horizontalSizeClass) private var hsc
    enum Tab: String, CaseIterable { case kept = "품은 말씀", notes = "남긴 한 줄", calendar = "달력" }
    @State private var tab: Tab = .kept
    @State private var picked: Bookmark?
    @State private var share: ShareVerses?
    @State private var note: KeptNote?
    @State private var noteTick = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                if SarakLayout(size: geo.size) == .spread {
                    HStack(spacing: 0) {
                        list.frame(width: (geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing) / 2 - geo.safeAreaInsets.leading)
                        detail.padding(.horizontal, 36).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else { list.frame(maxWidth: 760).frame(maxWidth: .infinity) }
            }
            .background(Ink.canvas).toolbar(.hidden, for: .navigationBar)
        }
        .tint(Ink.ink)
        .onAppear {
            store.reload(); path.reload()
            #if DEBUG
            if Demo.screen == "calendar" { tab = .calendar } else if Demo.screen == "notes" { tab = .notes }
            #endif
        }
        .sheet(item: $note) { n in NoteSheet(note: n, inGroup: store.activeGroupId != nil && n.isPlan) { saveNote(n, $0) } }
        .sheet(item: $share) { s in ShareCardSheet(verses: s.verses, bookName: s.bookName, note: nil, dayNumber: nil) }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("말씀첩")
                HStack(spacing: 24) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        Button { tab = t } label: {
                            Text(t.rawValue).font(tab == t ? .subheadline.weight(.semibold) : .subheadline).foregroundStyle(tab == t ? Ink.ink : Ink.sub)
                                .frame(minHeight: 44).overlay(alignment: .bottom) { if tab == t { Rectangle().fill(Ink.ink).frame(height: 2) } }
                        }
                        .accessibilityAddTraits(tab == t ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1).zIndex(-1) }
                .padding(.bottom, 8)
                switch tab {
                case .kept: kept
                case .notes: notes
                case .calendar: ReadCalendar(dates: readDates)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    @ViewBuilder private var kept: some View {
        if store.bookmarks.isEmpty { empty("아직 비어 있어요.", "읽다가 마음에 머무는 구절을 눌러\n품어 보세요.") }
        ForEach(store.bookmarks) { b in
            Button { picked = b; if hsc == .compact { share = ShareVerses(verses: [verse(b)], bookName: b.bookName) } } label: {
                row(hour: PlanDates.parse(b.savedAt).map(SarakHour.at) ?? .morning, b.text, "\(b.bookName) \(b.chapter):\(b.verse)")
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button { share = ShareVerses(verses: [verse(b)], bookName: b.bookName) } label: { Label("나누기", systemImage: "square.and.arrow.up") }
                Button(role: .destructive) { store.toggleBookmark(verse(b), bookName: b.bookName) } label: { Label("내려놓기", systemImage: "bookmark.slash") }
            }
        }
    }
    @ViewBuilder private var notes: some View {
        let _ = noteTick
        let all = noteItems
        if all.isEmpty { empty("아직 남긴 글이 없어요.", "본문을 마칠 때 한 줄 남길 수 있어요.") }
        ForEach(all) { n in
            Button { note = n } label: { row(hour: SarakHour.at(n.date), n.text, "\(n.reference)  \(n.date.koreanDay)") }.buttonStyle(.plain)
        }
    }
    private var noteItems: [KeptNote] {
        var out: [KeptNote] = []
        for (d, e) in path.completed { if let c = e.comment, !c.isEmpty, let t = e.date { out.append(KeptNote(origin: .path(d), text: c, reference: Reading.path(WordPath.mark.day(d)).title, date: t)) } }
        for (d, e) in store.completed { if let c = e.comment, !c.isEmpty, let t = e.date { out.append(KeptNote(origin: .plan(d), text: c, reference: store.plan?.day(d)?.displayRange ?? "", date: t)) } }
        for n in Prefs.json("word_notes", as: [WordNote].self) ?? [] { if let t = PlanDates.parse(n.savedAt) { out.append(KeptNote(origin: .alert(n.id), text: n.text, reference: n.reference, date: t)) } }
        return out.sorted { $0.date > $1.date }
    }
    private func saveNote(_ n: KeptNote, _ text: String?) {
        switch n.origin {
        case .path(let d): path.setNote(day: d, text)
        case .plan(let d): store.setNote(day: d, text)
        case .alert(let id):
            var list = Prefs.json("word_notes", as: [WordNote].self) ?? []
            if let i = list.firstIndex(where: { $0.id == id }) { if let text { list[i].text = text } else { list.remove(at: i) } }
            Prefs.setJSON(list, "word_notes")
        }
        noteTick += 1
    }
    private var readDates: Set<Date> {
        Set((Array(path.completed.values) + Array(store.completed.values)).compactMap { $0.date.map(Calendar.current.startOfDay) })
    }
    private func verse(_ b: Bookmark) -> Verse { Verse(bookId: b.bookId, chapter: b.chapter, number: b.verse, text: b.text) }

    private func row(hour: SarakHour, _ text: String, _ ref: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Ribbon().fill(hour.ribbon).frame(width: 12, height: 22).overlay(Ribbon().stroke(Ink.ink.opacity(0.12), lineWidth: 0.5)).padding(.top, 4).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(text).font(SarakFont.serif(19)).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                    Text(ref).font(.footnote).foregroundStyle(Ink.sub)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 20)
            Rectangle().fill(Ink.line).frame(height: 1)
        }
        .contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
    private func empty(_ t: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t).font(SarakFont.serif(22)).foregroundStyle(Ink.ink)
            Text(s).font(.subheadline).foregroundStyle(Ink.sub)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 48)
    }
    @ViewBuilder private var detail: some View {
        if let b = picked ?? store.bookmarks.first {
            VStack(alignment: .leading, spacing: 28) {
                VerseText(text: b.text, source: "\(b.bookName) \(b.chapter):\(b.verse)", size: 32)
                Button("나누기") { share = ShareVerses(verses: [verse(b)], bookName: b.bookName) }.buttonStyle(SarakButtonStyle(quiet: true)).frame(maxWidth: 240)
            }.padding(.top, 24)
        }
    }
}

struct KeptNote: Identifiable, Hashable {
    enum Origin: Hashable { case path(Int), plan(Int), alert(String) }
    let origin: Origin, text: String, reference: String, date: Date
    var id: Origin { origin }
    var isPlan: Bool { if case .plan = origin { true } else { false } }
}

/// 남긴 한 줄을 펼쳐 보고, 고치고, 지웁니다.
struct NoteSheet: View {
    let note: KeptNote
    let inGroup: Bool
    let save: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var confirm = false
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(note.date.koreanFullDate)에 남긴 글").font(.footnote).foregroundStyle(Ink.sub)
                    TextField("한 줄", text: $text, axis: .vertical).font(SarakFont.serif(20)).lineSpacing(6).foregroundStyle(Ink.ink)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    Rectangle().fill(Ink.line).frame(height: 1)
                    Text("글을 눌러 고칠 수 있어요. 지워도 읽은 기록은 남아요.\(inGroup ? " 그룹에 이미 보인 글은 바뀌지 않아요." : "")").font(.footnote).foregroundStyle(Ink.sub)
                    Button("이 글 지우기") { confirm = true }.font(.body).foregroundStyle(Ink.danger).frame(minHeight: 44)
                }
                .padding(24)
            }
            .background(Ink.canvas)
            .navigationTitle(note.reference).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { save(trimmed); dismiss() }.disabled(trimmed.isEmpty || trimmed == note.text) }
            }
            .alert("이 글을 지울까요?", isPresented: $confirm) {
                Button("지우기", role: .destructive) { save(nil); dismiss() }
                Button("취소", role: .cancel) {}
            } message: { Text("지운 글은 되돌릴 수 없어요.") }
        }
        .tint(Ink.ink)
        .presentationDetents([.medium, .large])
        .onAppear { text = note.text }
    }
}

struct Ribbon: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: r.origin); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.width * 0.5)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath()
        return p
    }
}

/// 읽은 날에 종이가 놓입니다. 빈 날을 따로 표시하지 않습니다.
struct ReadCalendar: View {
    let dates: Set<Date>
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    private let cal = Calendar.current
    var body: some View {
        let c = cal.dateComponents([.year, .month], from: month)
        let days = cal.range(of: .day, in: .month, for: month)!.map { cal.date(byAdding: .day, value: $0 - 1, to: month)! }
        let lead = (cal.component(.weekday, from: month) + 5) % 7
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(verbatim: "\(c.year!)년 \(c.month!)월").font(SarakFont.serif(20))
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("이전 달")
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("다음 달")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) { Text($0).font(.footnote).foregroundStyle(Ink.sub) }
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 46) }
                ForEach(days, id: \.self) { d in
                    let read = dates.contains(d), today = cal.isDateInToday(d)
                    Text("\(cal.component(.day, from: d))").font(.callout.monospacedDigit()).foregroundStyle(Ink.ink)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(read ? SarakHour.morning.page : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(alignment: .bottom) { if read { Rectangle().fill(Ink.control).frame(height: 2).padding(.horizontal, 5) } }
                        .overlay { if today { RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.ink, lineWidth: 1.5) } }
                        .accessibilityLabel("\(cal.component(.day, from: d))일\(read ? ", 읽은 날" : "")\(today ? ", 오늘" : "")")
                }
            }
            Text("종이가 놓인 날은 말씀을 읽은 날이에요.").font(.footnote).foregroundStyle(Ink.sub)
        }
        .foregroundStyle(Ink.ink).padding(.top, 8)
    }
    private func shift(_ n: Int) { month = cal.date(byAdding: .month, value: n, to: month)! }
}
