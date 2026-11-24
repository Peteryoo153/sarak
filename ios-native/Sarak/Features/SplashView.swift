import SwiftUI

/// 골방 문이 열리고 빛이 들어옵니다.
struct SplashView: View {
    var onFinish: () -> Void
    @State private var open: CGFloat = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var still
    var body: some View {
        ZStack(alignment: .topLeading) {
            DoorScene(open: open, floor: 0.68).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 8) {
                Text("사락").font(SarakFont.serif(44)).foregroundStyle(Ink.ink)
                Text("말씀이 사락사락 넘어갑니다").font(.subheadline).foregroundStyle(Ink.ink)
            }
            .opacity(shown ? 1 : 0).padding(.horizontal, 32).padding(.top, 48)
        }
        .task {
            if still { open = 1; shown = true } else {
                withAnimation(.easeOut(duration: 0.4)) { shown = true }
                withAnimation(.easeInOut(duration: 0.8)) { open = 1 }
            }
            try? await Task.sleep(for: .milliseconds(1200))
            onFinish()
        }
        #if DEBUG
        .onAppear { if Demo.screen == "splash" { open = 1; shown = true } }
        #endif
    }
}
