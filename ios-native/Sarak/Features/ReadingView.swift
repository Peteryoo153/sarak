import SwiftUI

struct ReadingView: View {
    let day: DayPlan
    @Environment(PlanStore.self) private var store
    @Environment(Session.self) private var session
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var verses: [Verse] = []
    @State private var selected: Set<Int> = []
    @State private var showSettings = false
    @State private var showComplete = false
    @State private var shareVerses: ShareVerses?
    @State private var toast: String?

    private var ref: ChapterRef { day.chapters[min(index, day.chapters.count - 1)] }
    private var isLast: Bool { index >= day.chapters.count - 1 }
    private var selectedVerses: [Verse] { verses.filter { selected.contains($0.number) } }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(ref.bookName) · Day \(day.dayNumber)")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(SarakColor.mintInk)
                            .id("top")
                        Text("\(ref.chapter)장").font(SarakFont.serif(34, bold: true)).foregroundStyle(SarakColor.ink)
                            .padding(.bottom, 14)
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(verses) { v in verseRow(v) }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                }
                .onChange(of: index) { _, _ in
                    load()
                    proxy.scrollTo("top", anchor: .top)
                }
            }
            .background(SarakColor.surface)
            .overlay(alignment: .bottom) { selectionBar }
            .safeAreaInset(edge: .bottom) { footer }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").fontWeight(.semibold) }
                        .accessibilityLabel("닫기")
                }
                ToolbarItem(placement: .principal) { chapterPills }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Text("가").font(SarakFont.serif(18, bold: true)) }
                        .accessibilityLabel("읽기 설정")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(SarakColor.surface, for: .navigationBar)
            .tint(SarakColor.ink)
            .sheet(isPresented: $showSettings) { ReadingSettingsSheet().presentationDetents([.height(360)]) }
            .sheet(isPresented: $showComplete) {
                CompletionSheet(day: day, keyVerses: selectedVerses.isEmpty ? Array(verses.prefix(1)) : selectedVerses,
                                bookName: ref.bookName) { dismiss() }
                    .presentationDetents([.large])
            }
            .sheet(item: $shareVerses) { sv in
                ShareCardSheet(verses: sv.verses, bookName: sv.bookName, note: nil, dayNumber: day.dayNumber)
            }
            .overlay(alignment: .top) {
                if let toast {
                    Text(toast).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color(hex: 0x17153B).opacity(0.92), in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        verses = BibleDB.shared.chapter(bookId: ref.bookId, chapter: ref.chapter)
        selected = []
    }

    private var chapterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(day.chapters.enumerated()), id: \.offset) { i, c in
                    let crossesBook = day.chapters.first?.bookId != day.chapters.last?.bookId
                    Button(crossesBook ? "\(c.bookName.prefix(2)) \(c.chapter)" : "\(c.chapter)장") { index = i }
                        .buttonStyle(PillButtonStyle(selected: i == index))
                }
            }
        }
        .frame(maxWidth: 240)
    }

    private func verseRow(_ v: Verse) -> some View {
        let isSel = selected.contains(v.number)
        let marked = store.isBookmarked(v)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(v.number)")
                .font(.system(size: 12, weight: isSel ? .bold : .semibold))
                .foregroundStyle(isSel ? SarakColor.mintInk : SarakColor.inkMuted)
                .frame(minWidth: 18, alignment: .leading)
            Text(v.text)
                .font(settings.useSerif ? SarakFont.serif(settings.fontSize) : .system(size: settings.fontSize))
                .lineSpacing(settings.fontSize * 0.5)
                .foregroundStyle(SarakColor.ink)
                .underline(isSel, color: SarakColor.mintInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            if marked {
                Image(systemName: "bookmark.fill").font(.system(size: 11)).foregroundStyle(SarakColor.streak)
                    .accessibilityLabel("북마크됨")
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 10)
        .background(isSel ? SarakColor.mintSoft : .clear, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .padding(.horizontal, -10)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) {
                if isSel { selected.remove(v.number) } else { selected.insert(v.number) }
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("눌러서 구절 선택")
    }

    @ViewBuilder private var selectionBar: some View {
        if !selected.isEmpty {
            HStack(spacing: 2) {
                Text(selectionLabel).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.leading, 12)
                Spacer()
                barButton("저장", "bookmark") {
                    for v in selectedVerses { store.toggleBookmark(v, bookName: ref.bookName) }
                    flash("북마크를 바꿨어요"); selected = []
                }
                barButton("복사", "doc.on.doc") {
                    UIPasteboard.general.string = shareText
                    flash("복사했어요"); selected = []
                }
                Button {
                    shareVerses = ShareVerses(verses: selectedVerses, bookName: ref.bookName)
                } label: {
                    Label("말씀 카드", systemImage: "rectangle.portrait.on.rectangle.portrait")
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(SarakColor.indigo)
                        .padding(.horizontal, 12).frame(height: 40)
                        .background(SarakColor.mint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(6)
            .frame(height: 56)
            .background(Color(hex: 0x17153B), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func barButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 10).frame(height: 44)
        }
    }

    private var selectionLabel: String {
        let nums = selected.sorted()
        guard let f = nums.first, let l = nums.last else { return "" }
        return f == l ? "\(f)절" : nums.count == l - f + 1 ? "\(f)–\(l)절" : "\(nums.count)개 구절"
    }

    private var shareText: String {
        let body = selectedVerses.map { "\($0.number) \($0.text)" }.joined(separator: "\n")
        return "\(body)\n— \(ref.bookName) \(ref.chapter):\(selectionLabel.replacingOccurrences(of: "절", with: ""))"
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { if index > 0 { index -= 1 } } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                    .frame(width: 56, height: 56)
                    .foregroundStyle(index > 0 ? SarakColor.ink : SarakColor.inkFaint)
                    .background(SarakColor.raised, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(SarakColor.line))
            }
            .disabled(index == 0)
            .accessibilityLabel("이전 장")

            if isLast {
                Button { showComplete = true } label: { Label("오늘 읽기 마무리", systemImage: "checkmark") }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                let next = day.chapters[index + 1]
                Button { index += 1 } label: {
                    HStack(spacing: 6) {
                        Text(next.bookId == ref.bookId ? "다음 장 · \(next.chapter)장" : "다음 · \(next.bookName) \(next.chapter)장")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
        .background(SarakColor.raised.shadow(.drop(color: .black.opacity(0.04), radius: 0, y: -1)))
    }

    private func flash(_ s: String) {
        withAnimation { toast = s }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { toast = nil }
        }
    }
}

struct ShareVerses: Identifiable {
    let verses: [Verse]
    let bookName: String
    var id: String { verses.map(\.id).joined() }
}

struct ReadingSettingsSheet: View {
    @Environment(ReadingSettings.self) private var settings
    @AppStorage("appearance") private var appearance: AppearanceMode = .system

    var body: some View {
        @Bindable var s = settings
        VStack(alignment: .leading, spacing: 20) {
            Text("읽기 설정").font(SarakFont.title2).foregroundStyle(SarakColor.ink)
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "글자 크기")
                HStack(spacing: 12) {
                    Text("가").font(.system(size: 14))
                    Slider(value: $s.fontSize, in: 14...28, step: 1)
                    Text("가").font(.system(size: 24))
                }
                .foregroundStyle(SarakColor.ink)
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "글꼴")
                HStack(spacing: 8) {
                    Button("명조 (고운바탕)") { s.useSerif = true }.buttonStyle(PillButtonStyle(selected: s.useSerif))
                    Button("고딕") { s.useSerif = false }.buttonStyle(PillButtonStyle(selected: !s.useSerif))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "화면 모드")
                HStack(spacing: 8) {
                    ForEach(AppearanceMode.allCases) { m in
                        Button(m == .system ? "시스템" : m.label) { appearance = m }.buttonStyle(PillButtonStyle(selected: appearance == m))
                    }
                }
            }
            Text("태초에 하나님이 천지를 창조하시니라")
                .font(s.useSerif ? SarakFont.serif(s.fontSize) : .system(size: s.fontSize))
                .foregroundStyle(SarakColor.ink)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SarakColor.surface)
    }
}
