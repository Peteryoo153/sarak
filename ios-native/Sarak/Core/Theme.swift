import SwiftUI
import UIKit

// MARK: - Color tokens (사락 Sarak 디자인 시스템 · Paper / Night)

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) { self.init(uiColor: .dynamic(light: light, dark: dark)) }
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

enum SarakColor {
    static let indigo = Color(hex: 0x1A166E)
    static let indigoDeep = Color(light: 0x110E4A, dark: 0x0C0A36)
    /// 히어로 카드 바탕. 다크 모드에서도 브랜드 인디고를 유지하되 살짝 밝게.
    static let hero = Color(light: 0x1A166E, dark: 0x221D86)
    static let mint = Color(hex: 0x6EE7B7)
    static let mintInk = Color(light: 0x0E7A55, dark: 0x6EE7B7)
    static let mintSoft = Color(light: 0xDDF7EB, dark: 0x123B32)
    static let surface = Color(light: 0xF7F6F1, dark: 0x121124)
    static let raised = Color(light: 0xFFFFFF, dark: 0x1C1B33)
    static let sunken = Color(light: 0xEFEDE6, dark: 0x0B0A1A)
    static let ink = Color(light: 0x17153B, dark: 0xEEEDF7)
    static let inkMuted = Color(light: 0x5E5C7A, dark: 0xA9A7C4)
    static let inkFaint = Color(light: 0x8F8DA8, dark: 0x77759A)
    static let onIndigo = Color.white
    static let onIndigoMuted = Color(hex: 0xB9B6E6)
    static let line = Color(light: 0xE3E1EA, dark: 0x2C2A48)
    static let danger = Color(light: 0xC0392B, dark: 0xFF8A7A)
    static let streak = Color(light: 0xC26A12, dark: 0xF5B266)
    /// 인디고 배경 위 버튼(주요 버튼) — 다크 모드에서는 민트로 반전
    static let primaryFill = Color(light: 0x1A166E, dark: 0x6EE7B7)
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x1A166E)

    static let avatar: [Color] = [
        Color(hex: 0x1A166E), Color(hex: 0x0E7A55), Color(hex: 0xC26A12), Color(hex: 0x5E5C7A),
        Color(hex: 0x2E6BE6), Color(hex: 0xA23B72), Color(hex: 0x3F7F8C), Color(hex: 0x7A5C2E),
    ]
}

// MARK: - Type

enum SarakFont {
    static func serif(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "GowunBatang-Bold" : "GowunBatang-Regular", size: size)
    }
    static let display = Font.system(size: 34, weight: .heavy)
    static let title1 = Font.system(size: 26, weight: .heavy)
    static let title2 = Font.system(size: 20, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 16)
    static let callout = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13, weight: .medium)
    static let micro = Font.system(size: 11, weight: .semibold)
}

enum Radius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
}

// MARK: - Appearance preference

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "시스템 설정 따르기"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Components

struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = SarakColor.primaryFill
    var foreground: Color = SarakColor.onPrimary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .heavy))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(foreground)
            .background(fill.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(SarakColor.ink)
            .background(SarakColor.raised, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(SarakColor.line))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct PillButtonStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: selected ? .bold : .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .foregroundStyle(selected ? SarakColor.onPrimary : SarakColor.inkMuted)
            .background(selected ? SarakColor.primaryFill : SarakColor.raised, in: Capsule())
            .overlay(Capsule().stroke(selected ? .clear : SarakColor.line))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 20
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SarakColor.raised, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                if scheme == .dark {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(SarakColor.line)
                }
            }
            .shadow(color: scheme == .dark ? .clear : Color(hex: 0x17153B).opacity(0.06), radius: 12, y: 6)
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View { modifier(CardModifier(padding: padding)) }
}

struct HeroCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(SarakColor.onIndigo)
            .background {
                ZStack(alignment: .topTrailing) {
                    SarakColor.hero
                    PageStrokes()
                        .stroke(SarakColor.mint.opacity(0.22), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 180, height: 180)
                        .offset(x: 36, y: -28)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

/// 로고의 책장 선을 본뜬 장식 패턴
struct PageStrokes: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 180
        var p = Path()
        let lines: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(40, 10, 110, 146), (56, 22, 104, 136), (72, 34, 98, 124)]
        for (x, top, bend, endY) in lines {
            p.move(to: CGPoint(x: x * s, y: top * s))
            p.addLine(to: CGPoint(x: x * s, y: bend * s))
            p.addQuadCurve(to: CGPoint(x: (x + 24) * s, y: endY * s), control: CGPoint(x: x * s, y: (bend + 24) * s))
            p.addLine(to: CGPoint(x: 172 * s, y: (endY + 24) * s))
        }
        return p
    }
}

struct DayBadge: View {
    let text: String
    var onIndigo = true
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(onIndigo ? SarakColor.mint : SarakColor.mintInk)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(onIndigo ? SarakColor.mint.opacity(0.15) : SarakColor.mintSoft, in: Capsule())
    }
}

struct AvatarView: View {
    let name: String
    var index: Int = 0
    var size: CGFloat = 40
    var body: some View {
        Text(Self.initials(name))
            .font(.system(size: size * 0.33, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(SarakColor.avatar[abs(index) % SarakColor.avatar.count], in: Circle())
    }
    /// 한국어 이름은 성을 빼고 이름 두 글자, 그 외에는 첫 글자
    static func initials(_ name: String) -> String {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return "?" }
        if t.unicodeScalars.allSatisfy({ (0xAC00...0xD7A3).contains($0.value) }) && t.count >= 3 {
            return String(t.suffix(2))
        }
        return String(t.prefix(t.unicodeScalars.first.map { (0xAC00...0xD7A3).contains($0.value) } == true ? 2 : 1))
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(SarakColor.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Date {
    var koreanFullDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: self)
    }
}
