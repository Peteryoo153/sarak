import SwiftUI

/// 사락 로고: 빛이 새는 골방. 앱 아이콘과 같은 그림이며 open(0…1)으로 문이 열립니다.
struct DoorScene: View, Animatable {
    var open: CGFloat = 1
    /// 바닥선의 높이(위에서부터의 비율). 정사각 로고는 0.725
    var floor: CGFloat = 0.725
    var animatableData: CGFloat { get { open } set { open = newValue } }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in
            let dark = scheme == .dark
            func c(_ l: UInt32, _ d: UInt32) -> Color { Color(hex: dark ? d : l) }
            func grad(_ a: Color, _ b: Color, _ r: CGRect, horizontal: Bool = false) -> GraphicsContext.Shading {
                .linearGradient(Gradient(colors: [a, b]), startPoint: r.origin,
                                endPoint: horizontal ? CGPoint(x: r.maxX, y: r.minY) : CGPoint(x: r.minX, y: r.maxY))
            }
            let w = size.width, h = size.height, y = h * floor
            let k = min(w, h) / 1024, cx = w / 2
            func X(_ v: CGFloat) -> CGFloat { cx + (v - 512) * k }
            func Y(_ v: CGFloat) -> CGFloat { y + (v - 742) * k }
            func poly(_ p: [CGPoint]) -> Path { var q = Path(); q.addLines(p); q.closeSubpath(); return q }

            let wall = CGRect(x: 0, y: 0, width: w, height: y), ground = CGRect(x: 0, y: y, width: w, height: h - y)
            ctx.fill(Path(wall), with: grad(c(0xD9CFEA, 0x3D3650), c(0xB8A9D6, 0x272236), wall))
            ctx.fill(Path(ground), with: grad(c(0xF8D9CB, 0x4A3A3A), c(0xF0BBA4, 0x352928), ground))

            // 빛은 열린 만큼만 보입니다
            let right = 322 + 320 * max(open, 0.04), drop = (h - y) / k
            ctx.fill(poly([CGPoint(x: X(322), y: y), CGPoint(x: X(right), y: y),
                           CGPoint(x: X(right + drop * 1.02 * open), y: h), CGPoint(x: X(322 - drop * 0.61 * open), y: h)]),
                     with: grad(c(0xFFF0C6, 0xF6DFA6), c(0xF9D48A, 0xB98F52), ground))
            let frame = CGRect(x: X(322), y: Y(214), width: 320 * k, height: 528 * k)
            ctx.fill(Path(roundedRect: frame, cornerRadius: 10 * k), with: grad(Color(hex: 0xFFF6DF), Color(hex: 0xFBD98F), frame))

            // 문짝: 오른쪽 경첩을 축으로 열립니다 (-320 닫힘 → 170 열림)
            let edge = 642 - 320 + 490 * open, lean = 66 * max(0, min(1, open)), low = 100 * max(0, min(1, open))
            let door = poly([CGPoint(x: X(642), y: Y(208)), CGPoint(x: X(edge), y: Y(214 - lean)),
                             CGPoint(x: X(edge), y: Y(742 + low)), CGPoint(x: X(642), y: Y(742))])
            var d = ctx
            d.addFilter(.shadow(color: Color(hex: 0x6B4436).opacity(0.20), radius: 16 * k, y: 12 * k))
            d.fill(door, with: grad(c(0xFBE6DB, 0xCDBBB2), c(0xFFFFFF, 0xF4E8E0), door.boundingRect, horizontal: true))
        }
        .accessibilityHidden(true)
    }
}

/// 작은 로고 (앱 아이콘 모양)
struct DoorLogo: View {
    var size: CGFloat = 64
    var body: some View { DoorScene().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)) }
}
