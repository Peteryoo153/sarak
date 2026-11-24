import SwiftUI

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
    var ground: SarakHour = .now

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
            SarakPage(hour: ground, lift: format == .story ? 120 : 64)
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 12)
                Text(quote).font(SarakFont.serif(quoteSize)).lineSpacing(quoteSize * 0.12).foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(reference).font(.system(size: 14)).foregroundStyle(Ink.sub).padding(.top, 14)
                if let note, format == .story {
                    Text(note).font(.system(size: 13)).lineSpacing(4).foregroundStyle(Ink.sub).lineLimit(3).padding(.top, 10)
                }
                HStack(spacing: 8) { DoorLogo(size: 24); Text("사락").font(SarakFont.serif(16)).foregroundStyle(Ink.ink) }.padding(.top, format == .story ? 72 : 24)
            }
            .padding(.horizontal, 30).padding(.top, 28).padding(.bottom, format == .story ? 130 : 30)
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
    private let grounds = SarakHour.allCases

    private var card: ShareCard {
        ShareCard(verses: verses, bookName: bookName, note: note, dayNumber: dayNumber, streak: store.streak,
                  format: format, ground: grounds[groundIndex])
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
                        
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack(spacing: 12) {
                    ForEach(Array(grounds.enumerated()), id: \.offset) { i, g in
                        Button { groundIndex = i } label: {
                            Circle().fill(g.page).frame(width: 36, height: 36)
                                .overlay(Circle().stroke(SarakColor.primaryFill, lineWidth: groundIndex == i ? 3 : 0).padding(-4))
                        }
                        .accessibilityLabel("배경 \(g.name)")
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
