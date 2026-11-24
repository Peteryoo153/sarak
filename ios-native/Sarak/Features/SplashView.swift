import SwiftUI

/// 종이 한 장이 사락 들립니다.
struct SplashView: View {
    var onFinish: () -> Void
    @State private var lift: CGFloat = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var still
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SarakPage(hour: .now, lift: lift).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 8) {
                Text("사락").font(SarakFont.serif(44)).foregroundStyle(Ink.ink)
                Text("말씀이 사락사락 넘어갑니다").font(.subheadline).foregroundStyle(Ink.sub)
            }
            .opacity(shown ? 1 : 0).padding(.horizontal, 32).padding(.bottom, 220)
        }
        .task {
            if still { shown = true; lift = 160 } else {
                withAnimation(.easeOut(duration: 0.35)) { shown = true }
                withAnimation(.easeInOut(duration: 0.7)) { lift = 160 }
            }
            try? await Task.sleep(for: .milliseconds(1000))
            onFinish()
        }
    }
}
