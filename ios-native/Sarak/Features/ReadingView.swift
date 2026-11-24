import SwiftUI

/// 본문 글. 절을 눌러 고릅니다. 화면 전체 읽기와 펼친 책 오른쪽 면이 함께 씁니다.
struct PassageBody: View {
    @Bindable var model: ReaderModel
    var onFinish: () -> Void
    @Environment(PlanStore.self) private var store
    @Environment(ReadingSettings.self) private var settings
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @State private var toast: String?
    @State private var share: ShareVerses?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(model.blocks) { b in
                    VStack(alignment: .leading, spacing: 8) {
                        if b.startsChapter && model.reading.segments.count > 1 {
                            Text("\(b.segment.bookName) \(b.segment.chapter)장").font(.footnote).foregroundStyle(Ink.sub)
                                .padding(.top, b.id == 0 ? 0 : 24).accessibilityAddTraits(.isHeader)
                        }
                        Text(attributed(b.verses))
                            .font(font).lineSpacing(size * (settings.useSerif ? 0.24 : 0.5)).tint(Ink.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .id(b.id)
                }
            }
            .scrollTargetLayout()
            .padding(.top, 12)
            Text(model.reading.kind == .free ? "여기까지예요." : "오늘의 본문은 여기까지예요.")
                .font(.subheadline).foregroundStyle(Ink.sub).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 28)
            if model.reading.kind != .free {
                Button("오늘 본문 마치기", action: onFinish).buttonStyle(SarakButtonStyle()).padding(.top, 24)
            }
            Color.clear.frame(height: 110)
        }
        .scrollPosition(id: $model.position, anchor: .top)
        .scrollIndicators(.hidden)
        .environment(\.openURL, OpenURLAction { u in
            guard u.scheme == "verse" else { return .systemAction }
            model.toggle(u.host() ?? ""); return .handled
        })
        .overlay(alignment: .bottom) { actions }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast).font(.subheadline).foregroundStyle(Ink.onPrimary).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Ink.primary, in: Capsule()).transition(.opacity)
            }
        }
        .sheet(item: $share) { s in ShareCardSheet(verses: s.verses, bookName: s.bookName, note: nil, dayNumber: nil) }
    }

    private var size: CGFloat { settings.fontSize * scale }
    private var font: Font { settings.useSerif ? .custom("GowunBatang-Regular", fixedSize: size) : .system(size: size) }

    private func attributed(_ verses: [Verse]) -> AttributedString {
        var out = AttributedString()
        for v in verses {
            var n = AttributedString("\(v.number)\u{00A0}")
            n.font = .system(size: max(size * 0.62, 11), weight: .medium); n.foregroundColor = Ink.sub; n.baselineOffset = size * 0.22
            var t = AttributedString(v.text.trimmingCharacters(in: .whitespaces))
            t.foregroundColor = Ink.ink
            t.link = URL(string: "verse://\(v.id)")
            if model.selected.contains(v.id) { t.backgroundColor = SarakHour.now.page; t.underlineStyle = .single }
            else if store.isBookmarked(v) { t.underlineStyle = Text.LineStyle(pattern: .dot, color: Ink.control) }
            out += n + t + AttributedString(" ")
        }
        return out
    }

    @ViewBuilder private var actions: some View {
        let picked = model.selectedVerses
        if !picked.isEmpty {
            HStack {
                act("품기", "bookmark") {
                    for v in picked where !store.isBookmarked(v) { store.toggleBookmark(v, bookName: model.bookName(v)) }
                    flash("마음에 품었어요")
                }
                act("복사", "doc.on.doc") {
                    UIPasteboard.general.string = picked.map(\.text).joined(separator: "\n") + "\n\(reference(picked))"
                    flash("복사했어요")
                }
                act("나누기", "square.and.arrow.up") { share = ShareVerses(verses: picked, bookName: model.bookName(picked[0])) }
                Button { model.selected = [] } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("선택 해제")
            }
            .padding(.horizontal, 12).frame(minHeight: 60).frame(maxWidth: 420)
            .foregroundStyle(Ink.ink)
            .background(Ink.raised, in: Capsule())
            .overlay(Capsule().strokeBorder(Ink.line))
            .shadow(color: .black.opacity(0.10), radius: 12, y: 8)
            .padding(.bottom, 12)
            .transition(.opacity)
        }
    }
    private func act(_ t: String, _ i: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) { Label(t, systemImage: i).font(.subheadline.weight(.medium)).lineLimit(1).frame(maxWidth: .infinity, minHeight: 44) }
    }
    private func reference(_ v: [Verse]) -> String {
        guard let f = v.first, let l = v.last else { return "" }
        let end = f.id == l.id ? "" : f.chapter == l.chapter ? "–\(l.number)" : "–\(l.chapter):\(l.number)"
        return "\(model.bookName(f)) \(f.chapter):\(f.number)\(end)"
    }
    private func flash(_ s: String) {
        model.selected = []
        withAnimation(.easeOut(duration: 0.25)) { toast = s }
        Task { try? await Task.sleep(for: .seconds(1.4)); withAnimation { toast = nil } }
    }
}

struct ReaderTools: View {
    @Bindable var model: ReaderModel
    @State private var settings = false
    var body: some View {
        HStack(spacing: 4) {
            Button { settings = true } label: { Text("가").font(SarakFont.serif(19)).frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("글자 설정")
            Button { model.speech.toggle(model.allText) } label: {
                Image(systemName: model.speech.speaking ? "pause" : "headphones").frame(minWidth: 44, minHeight: 44)
            }.accessibilityLabel(model.speech.speaking ? "듣기 멈추기" : "듣기")
        }
        .foregroundStyle(Ink.ink)
        .sheet(isPresented: $settings) { ReadingSettingsSheet().presentationDetents([.medium, .large]) }
    }
}

struct ReadingView: View {
    @Bindable var model: ReaderModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            PassageBody(model: model) { model.finishing = true }
                .frame(maxWidth: Space.measure).padding(.horizontal, 28).frame(maxWidth: .infinity)
                .background(Ink.canvas)
                .navigationTitle(model.reading.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button { model.speech.stop(); dismiss() } label: { Image(systemName: "chevron.left") }.accessibilityLabel("닫기") }
                    ToolbarItem(placement: .topBarTrailing) { ReaderTools(model: model) }
                }
                .toolbarBackground(Ink.canvas, for: .navigationBar)
                .fullScreenCover(isPresented: $model.finishing) { DoneView(model: model) { dismiss() } }
        }
        .tint(Ink.ink)
    }
}

/// 읽기를 마침
struct DoneView: View {
    let model: ReaderModel
    var onClose: () -> Void = {}
    @Environment(PathStore.self) private var path
    @Environment(PlanStore.self) private var store
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var note = ""
    @State private var lift: CGFloat = 40
    @State private var share = false
    @State private var shown: WordPath.Day?

    private var finishedBook: Bool { if case .path(let d) = model.reading.kind { return d == path.total && path.completed.count >= path.total - 1 }; return false }
    private var message: String {
        if finishedBook { return "마가복음 한 권을\n다 읽었어요.\n하루 5분이 여기까지\n데려왔네요." }
        if case .path = model.reading.kind { return "오늘 5분,\n마가복음이 사락\n한 장 더 넘어갔어요." }
        return "오늘의 본문이\n사락 한 장 더\n넘어갔어요."
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading) {
                        Spacer(minLength: 120)
                        VerseText(text: message, source: finishedBook ? "다음은 시편에서 잠시 쉬어가요." : model.reading.title, size: 34)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height * 0.62, alignment: .leading)
                    .padding(.horizontal, 28).padding(.bottom, 130)
                    .background {
                        SarakPage(hour: .now, lift: lift)
                            .padding(EdgeInsets(top: -geo.safeAreaInsets.top, leading: -geo.safeAreaInsets.leading, bottom: 0, trailing: -geo.safeAreaInsets.trailing))
                    }
                    VStack(spacing: 12) {
                        TextField("한 줄", text: $note, prompt: Text("감사나 묵상을 한 줄 남겨요 (선택)").foregroundStyle(Ink.sub), axis: .vertical).lineLimit(1...4)
                            .padding(16).background(Ink.raised, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Ink.control))
                        if store.activeGroupId != nil, case .plan = model.reading.kind {
                            Text("남긴 글은 함께 읽는 그룹에 보여요.").font(.footnote).foregroundStyle(Ink.sub)
                        }
                        Button("마치기") { finish() }.buttonStyle(SarakButtonStyle()).padding(.top, 12)
                        Button("함께 나누기") { share = true }.font(.body).foregroundStyle(Ink.ink).frame(minHeight: 44)
                    }
                    .frame(maxWidth: 460).padding(24)
                }
            }
            .scrollClipDisabled()
        }
        .background(Ink.canvas)
        .onAppear { still ? (lift = 120) : withAnimation(.easeOut(duration: 0.4)) { lift = finishedBook ? 180 : 120 } }
        .sheet(isPresented: $share) {
            let v = model.selectedVerses.isEmpty ? Array(model.blocks.first?.verses.prefix(1) ?? []) : model.selectedVerses
            ShareCardSheet(verses: v, bookName: model.reading.segments.first?.bookName ?? "", note: note.isEmpty ? nil : note, dayNumber: nil)
        }
    }

    private func finish() {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        switch model.reading.kind {
        case .path(let d): path.complete(day: d, note: text)
        case .plan(let d):
            store.markComplete(day: d.dayNumber, comment: text)
            let (g, p, s) = (store.activeGroupId, store.progress, store.streak)
            Task { await session.reportCompletion(groupId: g, day: d.dayNumber, comment: text.isEmpty ? nil : text, progress: p, streak: s) }
        case .free: break
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        model.speech.stop()
        dismiss(); onClose()
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
        Form {
            Section {
                Text("태초에 하나님이 천지를 창조하시니라").font(s.useSerif ? SarakFont.serif(s.fontSize) : .system(size: s.fontSize)).foregroundStyle(Ink.ink)
                Slider(value: $s.fontSize, in: 14...28, step: 1) { Text("글자 크기") } minimumValueLabel: { Text("가").font(.footnote) } maximumValueLabel: { Text("가").font(.title2) }
            }
            Section {
                Picker("글꼴", selection: $s.useSerif) { Text("고운바탕").tag(true); Text("고딕").tag(false) }
                Picker("화면", selection: $appearance) { ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) } }
            }
        }
        .tint(Ink.primary)
        .scrollContentBackground(.hidden).background(Ink.canvas)
    }
}
