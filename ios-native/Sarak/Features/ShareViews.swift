import SwiftUI

// MARK: - Completion sheet

struct CompletionSheet: View {
    let day: DayPlan
    let keyVerses: [Verse]
    let bookName: String
    var onDone: () -> Void

    @Environment(PlanStore.self) private var store
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var saved = false
    @State private var shareCard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark").font(.system(size: 24, weight: .heavy)).foregroundStyle(SarakColor.mintInk)
                        .frame(width: 52, height: 52).background(SarakColor.mintSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day \(day.dayNumber) 완료").font(.system(size: 22, weight: .heavy)).foregroundStyle(SarakColor.ink)
                        HStack(spacing: 4) {
                            Text(day.displayRange).foregroundStyle(SarakColor.inkMuted)
                            if saved && store.streak > 0 { Text("· \(store.streak)일 연속").fontWeight(.bold).foregroundStyle(SarakColor.streak) }
                        }
                        .font(.system(size: 14))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("오늘의 한마디").font(.system(size: 13, weight: .bold)).foregroundStyle(SarakColor.ink)
                        if store.activeGroupId != nil { Text("· 그룹에 함께 보여요").font(.system(size: 13)).foregroundStyle(SarakColor.inkMuted) }
                    }
                    TextField("마음에 남은 말씀을 적어보세요 (선택)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 15))
                        .padding(14)
                        .background(SarakColor.sunken, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(SarakColor.line))
                        .disabled(saved)
                }

                if saved {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("말씀 카드로 나누기").font(.system(size: 13, weight: .bold)).foregroundStyle(SarakColor.ink)
                        HStack(spacing: 12) {
                            ShareCard(verses: keyVerses, bookName: bookName, note: trimmedNote, dayNumber: day.dayNumber,
                                      streak: store.streak, format: .story, ground: SarakColor.indigo)
                                .frame(width: 360, height: 640)
                                .scaleEffect(84 / 360, anchor: .topLeading)
                                .frame(width: 84, height: 150, alignment: .topLeading)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .onTapGesture { shareCard = true }
                                .accessibilityHidden(true)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                                tile("인스타 스토리", "camera", primary: true) { instagram() }
                                tile("말씀 카드 꾸미기", "paintpalette") { shareCard = true }
                                tile("카톡 · 더보기", "square.and.arrow.up") { shareSheet() }
                                tile("같이 읽자고 보내기", "person.badge.plus") {
                                    ShareService.share([ShareService.readTogetherMessage(from: session.isSignedIn ? session.displayName : "친구", today: day)])
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(20)
            .padding(.top, 12)
        }
        .background(SarakColor.raised)
        .safeAreaInset(edge: .bottom) {
            Button(saved ? "닫기" : "읽기 완료") {
                if saved { dismiss(); onDone() } else { complete() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(SarakColor.raised)
        }
        .sheet(isPresented: $shareCard) {
            ShareCardSheet(verses: keyVerses, bookName: bookName, note: trimmedNote, dayNumber: day.dayNumber)
        }
    }

    private var trimmedNote: String? {
        let t = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func complete() {
        store.markComplete(day: day.dayNumber, comment: note.trimmingCharacters(in: .whitespacesAndNewlines))
        let groupId = store.activeGroupId
        let progress = store.progress, streak = store.streak
        Task { await session.reportCompletion(groupId: groupId, day: day.dayNumber, comment: trimmedNote, progress: progress, streak: streak) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(duration: 0.4)) { saved = true }
    }

    private func image(_ format: ShareCard.Format) -> UIImage? {
        ShareService.render(ShareCard(verses: keyVerses, bookName: bookName, note: trimmedNote, dayNumber: day.dayNumber,
                                      streak: store.streak, format: format, ground: SarakColor.indigo), size: format.size)
    }

    private func instagram() { if let img = image(.story) { ShareService.shareToInstagramStory(img) } }
    private func shareSheet() {
        if let img = image(.square) { ShareService.share([img, "\(day.displayRange) · 사락에서 함께 읽어요 \(AppLinks.appStore.absoluteString)"]) }
    }

    private func tile(_ title: String, _ icon: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(primary ? SarakColor.mint : SarakColor.ink)
                Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(primary ? .white : SarakColor.ink)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(primary ? SarakColor.indigo : SarakColor.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(primary ? .clear : SarakColor.line))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share card (rendered to image)

struct ShareCard: View {
    enum Format: String, CaseIterable, Identifiable {
        case story, square
        var id: String { rawValue }
        var size: CGSize { self == .story ? CGSize(width: 360, height: 640) : CGSize(width: 360, height: 360) }
        var label: String { self == .story ? "스토리 9:16" : "피드 1:1" }
    }

    let verses: [Verse]
    let bookName: String
    let note: String?
    let dayNumber: Int?
    var streak: Int = 0
    var format: Format = .story
    var ground: Color = SarakColor.indigo

    private var reference: String {
        guard let f = verses.first, let l = verses.last else { return bookName }
        return f.number == l.number ? "\(bookName) \(f.chapter):\(f.number)" : "\(bookName) \(f.chapter):\(f.number)–\(l.number)"
    }
    private var quote: String { verses.map(\.text).joined(separator: " ") }
    private var quoteSize: CGFloat {
        let n = quote.count
        let base: CGFloat = format == .story ? 24 : 19
        return n > 160 ? base - 6 : n > 90 ? base - 3 : base
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ground
            PageStrokes()
                .stroke(SarakColor.mint.opacity(0.16), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 280, height: 280)
                .offset(x: format.size.width - 150, y: format.size.height - (format == .story ? 250 : 200))
            VStack(alignment: .leading, spacing: 0) {
                if let dayNumber {
                    DayBadge(text: streak > 1 ? "Day \(dayNumber) · \(streak)일 연속" : "Day \(dayNumber)")
                }
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: format == .story ? 20 : 12) {
                    Image(systemName: "quote.opening").font(.system(size: 26, weight: .black)).foregroundStyle(SarakColor.mint)
                    Text(quote).font(SarakFont.serif(quoteSize, bold: true)).lineSpacing(quoteSize * 0.55)
                        .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                        .lineLimit(format == .story ? 12 : 6)
                    Text(reference).font(.system(size: 14, weight: .bold)).foregroundStyle(SarakColor.mint)
                    if let note, format == .story {
                        Text(note).font(.system(size: 13)).lineSpacing(4).foregroundStyle(SarakColor.onIndigoMuted).lineLimit(3)
                    }
                }
                Spacer(minLength: 12)
                Divider().overlay(SarakColor.onIndigoMuted.opacity(0.3))
                HStack(spacing: 10) {
                    Image("Logo").resizable().scaledToFit().frame(width: 18, height: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("사락").font(.system(size: 13, weight: .heavy)).tracking(2.6).foregroundStyle(.white)
                        Text("생명의 말씀이 사락 넘어갑니다").font(.system(size: 9, weight: .medium)).foregroundStyle(SarakColor.onIndigoMuted)
                    }
                    Spacer()
                    Text("App Store에서 사락").font(.system(size: 10, weight: .semibold)).foregroundStyle(SarakColor.onIndigoMuted)
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 30)
            .padding(.top, format == .story ? 60 : 28)
            .padding(.bottom, format == .story ? 40 : 22)
        }
        .frame(width: format.size.width, height: format.size.height)
        .clipped()
        .environment(\.colorScheme, .light)
    }
}

struct ShareCardSheet: View {
    let verses: [Verse]
    let bookName: String
    let note: String?
    let dayNumber: Int?
    @Environment(PlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var format: ShareCard.Format = .story
    @State private var groundIndex = 0
    @State private var savedToast = false
    private let grounds: [(String, Color)] = [("인디고", SarakColor.indigo), ("밤하늘", Color(hex: 0x110E4A)), ("숲", Color(hex: 0x0E5A42))]

    private var card: ShareCard {
        ShareCard(verses: verses, bookName: bookName, note: note, dayNumber: dayNumber, streak: store.streak,
                  format: format, ground: grounds[groundIndex].1)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("형식", selection: $format) {
                    ForEach(ShareCard.Format.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                GeometryReader { geo in
                    let s = min(geo.size.width / format.size.width, geo.size.height / format.size.height)
                    card
                        .scaleEffect(s)
                        .frame(width: format.size.width * s, height: format.size.height * s)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack(spacing: 12) {
                    ForEach(Array(grounds.enumerated()), id: \.offset) { i, g in
                        Button { groundIndex = i } label: {
                            Circle().fill(g.1).frame(width: 36, height: 36)
                                .overlay(Circle().stroke(SarakColor.primaryFill, lineWidth: groundIndex == i ? 3 : 0).padding(-4))
                        }
                        .accessibilityLabel("배경 \(g.0)")
                    }
                }
                .frame(height: 48)

                HStack(spacing: 10) {
                    Button { if let img = render() { ShareService.saveToPhotos(img); savedToast = true } } label: {
                        Label(savedToast ? "저장됨" : "사진에 저장", systemImage: savedToast ? "checkmark" : "arrow.down.to.line")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button { if let img = render() { ShareService.share([img]) } } label: { Label("공유", systemImage: "square.and.arrow.up") }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Button { if let img = render() { ShareService.shareToInstagramStory(img) } } label: {
                    Label("인스타그램 스토리에 올리기", systemImage: "camera")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .background(SarakColor.surface)
            .navigationTitle("말씀 카드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
    }

    private func render() -> UIImage? { ShareService.render(card, size: format.size) }
}
