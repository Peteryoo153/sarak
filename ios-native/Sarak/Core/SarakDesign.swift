import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// 사락 디자인 셋 · 빛이 물든 한 장
// tokens.json에서 만든 값입니다. 기존 SarakColor/SarakFont와 이름이 겹치지 않습니다.

extension Color {
    static func sarak(_ light: UInt32, _ dark: UInt32) -> Color {
        func rgb(_ h: UInt32) -> Color {
            Color(.sRGB, red: Double((h >> 16) & 255) / 255, green: Double((h >> 8) & 255) / 255, blue: Double(h & 255) / 255)
        }
        #if os(watchOS)
        return rgb(dark)
        #else
        return Color(uiColor: UIColor { UIColor(rgb($0.userInterfaceStyle == .dark ? dark : light)) })
        #endif
    }
}

enum Ink {
    static let canvas = Color.sarak(0xFDFBFA, 0x1F1A19)
    static let raised = Color.sarak(0xFFFFFF, 0x2A2321)
    static let ink = Color.sarak(0x40322F, 0xF6ECE6)
    static let sub = Color.sarak(0x6B5B57, 0xC6B6AE)
    static let line = Color.sarak(0xE9E0DC, 0x443935)
    static let control = Color.sarak(0x95837C, 0x8C7B74)
    static let primary = Color.sarak(0x4A3733, 0xF2D5C6)
    static let onPrimary = Color.sarak(0xFFFFFF, 0x3A2A26)
    static let danger = Color.sarak(0x9B3B36, 0xF2A79E)
}

/// 하루 네 번의 자리
enum SarakHour: String, CaseIterable, Codable, Identifiable {
    case morning, noon, rest, night
    var id: String { rawValue }
    var name: String { switch self { case .morning: "아침"; case .noon: "한낮"; case .rest: "쉼"; case .night: "밤" } }
    var next: SarakHour { let a = Self.allCases; return a[(a.firstIndex(of: self)! + 1) % a.count] }
    /// 종이 면
    var page: Color {
        switch self {
        case .morning: return .sarak(0xF8DFD3, 0x5A443C)
        case .noon: return .sarak(0xF5EACB, 0x494130)
        case .rest: return .sarak(0xDDE8DC, 0x36433A)
        case .night: return .sarak(0xE2DDEA, 0x3B3746)
        }
    }
    /// 들린 종이의 뒷면
    var flap: Color {
        switch self {
        case .morning: return .sarak(0xFDF0E9, 0x80675C)
        case .noon: return .sarak(0xFCF6E3, 0x6A6049)
        case .rest: return .sarak(0xEFF5EE, 0x526257)
        case .night: return .sarak(0xF2EFF6, 0x575164)
        }
    }
    /// 워치의 검은 바탕에 쓰는 밝은 색
    var glow: Color {
        switch self {
        case .morning: return .sarak(0xF8DFD3, 0xF8DFD3)
        case .noon: return .sarak(0xF5EACB, 0xF5EACB)
        case .rest: return .sarak(0xDDE8DC, 0xDDE8DC)
        case .night: return .sarak(0xE2DDEA, 0xE2DDEA)
        }
    }
}

enum Space {
    static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32, huge: CGFloat = 48
    static let margin: CGFloat = 24, measure: CGFloat = 560, touch: CGFloat = 44
}

/// 기기 이름이 아니라 안전 영역 안의 크기로 정합니다. (Duo 펼침 가로는 옆 시스템 띠를 빼고 약 867pt)
enum SarakLayout: Equatable {
    case single, wide, spread
    init(size: CGSize) { self = size.width < 600 ? .single : (size.width >= 820 && size.width > size.height) ? .spread : .wide }
}

// MARK: - 종이

/// 오른쪽 아래가 부드럽게 들린 종이. lift를 애니메이션하면 사락 넘어갑니다.
struct LiftedPage: Shape {
    var lift: CGFloat
    var layer: CGFloat = 1          // 1 = 종이, 0.42 = 뒷면
    var animatableData: CGFloat { get { lift } set { lift = newValue } }
    func path(in r: CGRect) -> Path {
        let c = lift * layer, w = r.maxX, h = r.maxY
        let span = min(r.width, 6 * max(lift, 1)), x = w - span
        var p = Path()
        p.move(to: r.origin)
        p.addLine(to: CGPoint(x: w, y: r.minY))
        p.addLine(to: CGPoint(x: w, y: h - c))
        p.addCurve(to: CGPoint(x: x, y: h),
                   control1: CGPoint(x: w - 0.22 * span, y: h - 0.70 * c),
                   control2: CGPoint(x: w - 0.46 * span, y: h))
        p.addLine(to: CGPoint(x: r.minX, y: h))
        p.closeSubpath()
        return p
    }
}

struct SarakPage: View {
    var hour: SarakHour
    var lift: CGFloat = 92
    var body: some View {
        ZStack {
            Rectangle().fill(hour.next.page)
            LiftedPage(lift: lift, layer: 0.42).fill(hour.flap)
            LiftedPage(lift: lift).fill(hour.page)
                .shadow(color: .black.opacity(0.10), radius: 4, y: 3)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - 말씀

struct VerseText: View {
    let text: String
    let source: String
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1
    var size: CGFloat = 36
    var color: Color = Ink.ink
    var sourceColor: Color = Ink.sub
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(text)
                .font(.custom("GowunBatang-Regular", fixedSize: size * scale))
                .tracking(-0.015 * size * scale)
                .lineSpacing(size * scale * 0.04)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)   // 말씀은 자르지 않습니다
            Text(source).font(.subheadline).foregroundStyle(sourceColor)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 부품

struct SarakButtonStyle: ButtonStyle {
    var quiet = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.xl).padding(.vertical, Space.m)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(!enabled ? Ink.sub : quiet ? Ink.ink : Ink.onPrimary)
            .background(!enabled ? Ink.line : quiet ? Color.clear : Ink.primary, in: RoundedRectangle(cornerRadius: 27))
            .overlay { if quiet { RoundedRectangle(cornerRadius: 27).strokeBorder(Ink.control) } }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// 시간의 색을 한 칸의 종이로 보여 주는 표시. 글자 이름과 늘 함께 씁니다.
struct HourChip: View {
    let hour: SarakHour
    var body: some View {
        RoundedRectangle(cornerRadius: 5).fill(hour.page)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Ink.ink.opacity(0.14)))
            .frame(width: 26, height: 34).accessibilityHidden(true)
    }
}

// MARK: - 골방 (한 장 / 펼친 책)

#if !os(watchOS)
struct RoomScreen<Tools: View, Action: View, Reading: View>: View {
    let hour: SarakHour
    let greeting: String
    let date: String
    let verse: String
    let source: String
    @ViewBuilder var tools: Tools
    @ViewBuilder var action: Action
    @ViewBuilder var reading: Reading          // 펼친 책의 오른쪽 면

    var body: some View {
        GeometryReader { geo in
            switch SarakLayout(size: geo.size) {
            case .spread:
                HStack(spacing: 0) {
                    page(bleed: geo.safeAreaInsets, full: true, bottom: 110, size: 38)
                        // 접힘선은 안전 영역이 아니라 화면 전체의 가운데
                        .frame(width: (geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing) / 2 - geo.safeAreaInsets.leading)
                    reading.frame(maxWidth: Space.measure).padding(.horizontal, 28).frame(maxWidth: .infinity)
                }
            case .single, .wide:
                ScrollView {
                    VStack(spacing: 0) {
                        page(bleed: geo.safeAreaInsets, full: false, bottom: 56, size: geo.size.width >= 600 ? 52 : 36)
                            .frame(minHeight: geo.size.height * (geo.size.height < 620 ? 0.68 : 0.74))
                        VStack(spacing: Space.m) { action }
                            .frame(maxWidth: 400).padding(Space.margin)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollClipDisabled()
            }
        }
        .background(Ink.canvas)
    }

    private func page(bleed i: EdgeInsets, full: Bool, bottom: CGFloat, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date).font(.footnote).foregroundStyle(Ink.sub)
                    Text(greeting).font(.body).foregroundStyle(Ink.ink)
                }
                Spacer()
                tools
            }
            Spacer(minLength: Space.huge)
            VerseText(text: verse, source: source, size: verse.count > 44 ? size * 0.72 : size)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, size > 40 ? 56 : 28).padding(.top, Space.l).padding(.bottom, bottom)
        // 종이는 상태 표시줄과 Duo의 옆 시스템 띠까지 이어지고, 글은 안전 영역 안에 둡니다.
        .background {
            SarakPage(hour: hour, lift: size > 40 ? 150 : 92)
                .padding(EdgeInsets(top: -i.top, leading: -i.leading, bottom: full ? -i.bottom : 0, trailing: full ? 0 : -i.trailing))
        }
    }
}
#endif

#if os(watchOS)
// MARK: - 워치 (검은 바탕, 시간의 색 글자)

struct WatchVerse: View {
    let hour: SarakHour
    let verse: String
    let source: String
    let next: String
    @Environment(\.isLuminanceReduced) private var dimmed
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 23
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verse.versed(8)).font(.custom("GowunBatang-Regular", fixedSize: size)).lineSpacing(1)
                        .foregroundStyle(dimmed ? Ink.sub : hour.glow).fixedSize(horizontal: false, vertical: true)
                    Text(source).font(.footnote).foregroundStyle(.secondary)
                    if !dimmed { Text(next).font(.caption2).foregroundStyle(.secondary).padding(.top, 18) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
            }
            // 종이 끝은 화면 바닥에 고정합니다. 어두워지면 끕니다.
            .background(alignment: .bottom) {
                if !dimmed {
                    ZStack {
                        Rectangle().fill(hour.next.page)
                        LiftedPage(lift: 46, layer: 0.42).fill(hour.glow)
                        LiftedPage(lift: 46).fill(.black)
                    }
                    .frame(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing, height: 60)
                    .padding(.bottom, -geo.safeAreaInsets.bottom)
                    .accessibilityHidden(true)
                }
            }
        }
        .background(Color.black)
    }
}
#endif
