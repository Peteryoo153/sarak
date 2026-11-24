import SwiftUI

/// 골방 문이 열리고 빛이 들어옵니다.
struct SplashView: View {
    var onFinish: () -> Void
    @State private var open: CGFloat = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var still
    var body: some View {
        DoorHero(open: open, shown: shown).ignoresSafeArea()
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
