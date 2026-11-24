import SwiftUI

struct BibleView: View {
    @Environment(PathStore.self) private var path
    @State private var old = false
    @State private var query = ""
    @State private var hits: [(book: String, verse: Verse)] = []
    @State private var model: ReaderModel?

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Button { model = ReaderModel(.path(path.today)) } label: { resume }
                        .buttonStyle(.plain).listRowInsets(EdgeInsets()).listRowSeparator(.hidden).listRowBackground(Color.clear)
                        .padding(.bottom, 12)
                    Picker("", selection: $old) { Text("구약").tag(true); Text("신약").tag(false) }
                        .pickerStyle(.segmented).labelsHidden().listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    ForEach(BibleDB.shared.books.filter { old ? $0.id < 40 : $0.id >= 40 }) { b in
                        NavigationLink { ChapterGrid(book: b) { model = ReaderModel(.chapter(b, $0)) } } label: {
                            LabeledContent { Text("\(b.chapterCount)장") } label: { Text(b.name).foregroundStyle(Ink.ink) }.frame(minHeight: 40)
                        }
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    }
                } else {
                    if hits.isEmpty { Text("찾는 말씀이 없어요.").foregroundStyle(Ink.sub).listRowBackground(Color.clear) }
                    ForEach(hits, id: \.verse.id) { h in
                        Button {
                            if let b = BibleDB.shared.books.first(where: { $0.id == h.verse.bookId }) {
                                let m = ReaderModel(.chapter(b, h.verse.chapter)); m.selected = [h.verse.id]; m.position = (h.verse.number - 1) / 6; model = m
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(h.verse.text).font(SarakFont.serif(17)).foregroundStyle(Ink.ink)
                                Text("\(h.book) \(h.verse.chapter):\(h.verse.number)").font(.footnote).foregroundStyle(Ink.sub)
                            }.padding(.vertical, 6)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain).contentMargins(.horizontal, 24, for: .scrollContent)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
            .background(Ink.canvas).navigationTitle("성경")
            .searchable(text: $query, prompt: "말씀 찾기")
            .onChange(of: query) { _, q in hits = q.count < 2 ? [] : BibleDB.shared.search(q) }
        }
        .tint(Ink.ink)
        .fullScreenCover(isPresented: Binding(get: { model != nil }, set: { if !$0 { model = nil } })) { if let model { ReadingView(model: model) } }
    }

    private var resume: some View {
        let r = Reading.path(path.today)
        let first = BibleDB.shared.chapter(bookId: 41, chapter: path.today.from.chapter).first { $0.number == path.today.from.verse }
        return VStack(alignment: .leading, spacing: 8) {
            Text("이어 읽기 · \(r.title)").font(.footnote).foregroundStyle(Ink.sub)
            Text(first?.text ?? "").font(SarakFont.serif(21)).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22).padding(.bottom, 36)
        .background { SarakPage(hour: .now, lift: 44) }
        .contentShape(Rectangle())
    }
}

struct ChapterGrid: View {
    let book: Book
    let onPick: (Int) -> Void
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                ForEach(1...max(book.chapterCount, 1), id: \.self) { c in
                    Button("\(c)") { onPick(c) }
                        .font(.body.monospacedDigit()).foregroundStyle(Ink.ink).frame(maxWidth: .infinity, minHeight: 56)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Ink.line))
                        .accessibilityLabel("\(c)장")
                }
            }
            .padding(24).frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity)
        .background(Ink.canvas).navigationTitle(book.name)
    }
}
