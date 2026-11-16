import SwiftUI

/// 인트로: 로고가 떠오르고, 세로쓰기 문구가 오른쪽 줄부터 한 줄씩 '사락' 넘어가듯 나타납니다.
struct SplashView: View {
    var onFinish: () -> Void
    @State private var logoIn = false
    @State private var linesIn = [false, false, false]
    @State private var footerIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lines: [(String, Bool)] = [
        ("일년 삼백육십오일 말씀과 함께", false),
        ("나를 넘어 우리 함께", false),
        ("말씀이 사라사락 넘어갑니다", true),
    ]

    var body: some View {
        ZStack {
            SarakColor.indigo.ignoresSafeArea()
            VStack(spacing: 40) {
                Image("Logo")
                    .resizable().scaledToFit()
                    .frame(width: 92, height: 132)
                    .opacity(logoIn ? 1 : 0)
                    .scaleEffect(logoIn ? 1 : 0.92)
                    .offset(y: logoIn ? 0 : 12)
                    .accessibilityLabel("사락")

                HStack(alignment: .top, spacing: 22) {
                    // 세로쓰기는 오른쪽 줄부터 읽으므로 배열을 뒤집어 배치합니다
                    ForEach(Array(lines.enumerated().reversed()), id: \.offset) { i, line in
                        VerticalText(text: line.0, highlighted: line.1)
                            .opacity(linesIn[i] ? 1 : 0)
                            .offset(y: linesIn[i] ? 0 : -10)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(lines.map(\.0).joined(separator: ", "))
            }
            .padding(.bottom, 40)

            VStack(spacing: 6) {
                Spacer()
                Text("사락").font(.system(size: 15, weight: .heavy)).tracking(6).foregroundStyle(.white)
                Text("SARAK BIBLE").font(.system(size: 11, weight: .semibold)).tracking(3.3).foregroundStyle(SarakColor.onIndigoMuted)
            }
            .padding(.bottom, 24)
            .opacity(footerIn ? 1 : 0)
        }
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            logoIn = true; linesIn = [true, true, true]; footerIn = true
            try? await Task.sleep(for: .milliseconds(900))
            onFinish(); return
        }
        withAnimation(.easeOut(duration: 0.6)) { logoIn = true }
        try? await Task.sleep(for: .milliseconds(350))
        for i in 0..<3 {
            withAnimation(.easeOut(duration: 0.5)) { linesIn[i] = true }
            try? await Task.sleep(for: .milliseconds(260))
        }
        withAnimation(.easeOut(duration: 0.4)) { footerIn = true }
        try? await Task.sleep(for: .milliseconds(850))
        onFinish()
    }
}

private struct VerticalText: View {
    let text: String
    let highlighted: Bool
    var body: some View {
        VStack(spacing: 7) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                if ch == " " {
                    Color.clear.frame(width: 1, height: 9)
                } else {
                    Text(String(ch))
                        .font(SarakFont.serif(19, bold: highlighted))
                        .foregroundStyle(highlighted ? SarakColor.mint : Color.white.opacity(0.92))
                }
            }
        }
    }
}
