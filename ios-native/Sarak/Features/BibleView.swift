import SwiftUI

struct BibleView: View {
    @Environment(PathStore.self) private var path
    @Environment(PlanStore.self) private var store
    @State private var old = false
    @State private var query = ""
    @State private var hits: [(book: String, verse: Verse)] = []
    @State private var model: ReaderModel?

    var body: some View {
        NavigationStack {
            List {
                VStack(spacing: 4) {
                    ScreenTitle("성경")
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Ink.sub).accessibilityHidden(true)
                        TextField("말씀 찾기", text: $query, prompt: Text("말씀 찾기").foregroundStyle(Ink.sub)).foregroundStyle(Ink.ink)
                            .autocorrectionDisabled().submitLabel(.search)
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Ink.control).frame(width: 44, height: 44) }
                                .buttonStyle(.plain).accessibilityLabel("지우기")
                        }
                    }
                    .font(.subheadline).frame(minHeight: 44)
                    .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                }
                .padding(.bottom, 16)
                .listRowInsets(EdgeInsets()).listRowSeparator(.hidden).listRowBackground(Color.clear)
                if query.isEmpty {
                    Button { model = ReaderModel(.today(store, path)) } label: { resume }
                        .buttonStyle(.plain).listRowInsets(EdgeInsets()).listRowSeparator(.hidden).listRowBackground(Color.clear)
                        .padding(.bottom, 12)
                    TextTabs(items: [(true, "구약"), (false, "신약")], selection: $old)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    ForEach(BibleDB.shared.books.filter { old ? $0.id < 40 : $0.id >= 40 }) { b in
                        NavigationLink { ChapterGrid(book: b) { model = ReaderModel(.chapter(b, $0)) } } label: {
                            LabeledContent { Text("\(b.chapterCount)장").font(.footnote).foregroundStyle(Ink.sub) } label: { Text(b.name).font(.subheadline).foregroundStyle(Ink.ink) }.frame(minHeight: 40)
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
                                Text(h.verse.text).font(SarakFont.serif(16)).lineSpacing(4).foregroundStyle(Ink.ink)
                                Text("\(h.book) \(h.verse.chapter):\(h.verse.number)").font(.footnote).foregroundStyle(Ink.sub)
                            }.padding(.vertical, 6)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain).scrollDismissesKeyboard(.immediately).contentMargins(.horizontal, 32, for: .scrollContent)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
            .background(Ink.canvas).toolbar(.hidden, for: .navigationBar)
            .onChange(of: query) { _, q in hits = q.count < 2 ? [] : BibleDB.shared.search(q) }
        }
        .tint(Ink.ink)
        .fullScreenCover(isPresented: Binding(get: { model != nil }, set: { if !$0 { model = nil } })) { if let model { ReadingView(model: model) } }
    }

    private var resume: some View {
        let r = Reading.today(store, path)
        let first = r.segments.first.flatMap { s in BibleDB.shared.chapter(bookId: s.bookId, chapter: s.chapter).first { $0.number >= s.from } }
        return VStack(alignment: .leading, spacing: 8) {
            Text("이어 읽기").font(.footnote).foregroundStyle(Ink.sub)
            Text(first?.text ?? "").font(SarakFont.serif(18)).lineSpacing(5).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
            Text(r.title).font(.footnote).foregroundStyle(Ink.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22).padding(.bottom, 36)
        .background { SarakPage(hour: .now, lift: 44) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
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
                        .font(.subheadline.monospacedDigit()).foregroundStyle(Ink.ink).frame(maxWidth: .infinity, minHeight: 56)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Ink.line))
                        .accessibilityLabel("\(c)장")
                }
            }
            .padding(32).frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity)
        .background(Ink.canvas).navigationTitle(book.name).navigationBarTitleDisplayMode(.inline)
    }
}
