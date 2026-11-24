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

/// 예전 이름을 쓰는 화면도 새 디자인의 색을 쓰도록 잇습니다. 새 화면은 Ink / SarakHour를 직접 씁니다.
enum SarakColor {
    static let mintInk = Ink.sub
    static let mintSoft = SarakHour.morning.page
    static let surface = Ink.canvas
    static let raised = Ink.raised
    static let sunken = Color(light: 0xF5F0ED, dark: 0x171312)
    static let ink = Ink.ink
    static let inkMuted = Ink.sub
    static let inkFaint = Ink.control
    static let line = Ink.line
    static let danger = Ink.danger
    static let primaryFill = Ink.primary
    static let onPrimary = Ink.onPrimary
    static let avatar: [Color] = SarakHour.allCases.map(\.page)
}

// MARK: - Type

enum SarakFont {
    static func serif(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "GowunBatang-Bold" : "GowunBatang-Regular", size: size)
    }
    static let display = Font.system(size: 34, weight: .semibold)
    static let title1 = Font.system(size: 26, weight: .semibold)
    static let title2 = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 16)
    static let callout = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13, weight: .medium)
    static let micro = Font.system(size: 11, weight: .semibold)
}

/// 탭 첫 화면의 제목. 내용과 같은 왼쪽 여백(24)에 놓습니다.
struct ScreenTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.custom("GowunBatang-Regular", size: 30, relativeTo: .largeTitle)).foregroundStyle(Ink.ink)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 20).padding(.bottom, 12)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 위쪽 막대의 가운데 제목도 같은 글꼴로 맞춥니다.
enum SarakBar {
    static func apply() {
        let font = UIFont(name: "GowunBatang-Bold", size: 18) ?? .systemFont(ofSize: 17, weight: .medium)
        UINavigationBar.appearance().titleTextAttributes = [.font: font, .foregroundColor: UIColor(Ink.ink)]
        let large = UIFont(name: "GowunBatang-Regular", size: 30) ?? .systemFont(ofSize: 30)
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: large, .foregroundColor: UIColor(Ink.ink)]
    }
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
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(foreground)
            .background(fill.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 27, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(SarakColor.ink)
            .background(SarakColor.raised, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous).strokeBorder(Ink.control))
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
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(SarakColor.line)
            }
            
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View { modifier(CardModifier(padding: padding)) }
}

struct HeroCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(24).padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Ink.ink)
            .background { SarakPage(hour: .now, lift: 44) }
    }
}

struct AvatarView: View {
    let name: String
    var index: Int = 0
    var size: CGFloat = 40
    var body: some View {
        Text(Self.initials(name))
            .font(.system(size: size * 0.33, weight: .semibold))
            .foregroundStyle(Ink.ink)
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
        Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(SarakColor.inkMuted)
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
