import SwiftUI

/// 문과 이름이 한 축에 놓이는 첫 그림. 시작 화면과 온보딩 첫 장이 같은 구도를 씁니다.
struct DoorHero: View {
    var open: CGFloat
    var shown = true
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                DoorScene(open: open, floor: 0.66)
                VStack(spacing: 10) {
                    Text("사락").font(.custom("GowunBatang-Regular", size: 28, relativeTo: .title)).tracking(4).padding(.leading, 4)
                        .accessibilityAddTraits(.isHeader)
                    Text("매일 조금씩, 말씀을 읽는 골방").font(.footnote).foregroundStyle(Ink.sub)
                }
                .foregroundStyle(Ink.ink).frame(maxWidth: .infinity).padding(.horizontal, 28)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .padding(.top, geo.size.height * 0.2)
                .opacity(shown ? 1 : 0)
            }
        }
    }
}

/// 첫 실행: 다섯 장의 종이. 들린 귀퉁이를 눌러 넘기고, 마지막 장에서 알림을 묻습니다.
struct WelcomeView: View {
    /// 설정에서 다시 볼 때는 알림을 묻지 않습니다.
    var revisit = false
    var done: () -> Void
    @State private var page = 0
    @State private var open: CGFloat = 0.1
    @State private var asking = false
    @Environment(\.accessibilityReduceMotion) private var still

    @Environment(\.dynamicTypeSize) private var type

    private struct Leaf { let hour: SarakHour, title: String, text: String }
    private let leaves = [
        Leaf(hour: .night, title: "", text: ""),
        Leaf(hour: .morning, title: "하루 5분이면\n한 권을 읽어요", text: "25일 동안 마가복음을 나누어 읽어요."),
        Leaf(hour: .noon, title: "머문 말씀은\n품어 두세요", text: "구절을 눌러 품으면 말씀첩에 모여요."),
        Leaf(hour: .rest, title: "혼자서도,\n함께여도", text: "가족, 교회와 같은 본문을 읽어요.\n그룹은 로그인한 뒤 쓸 수 있어요."),
        Leaf(hour: .night, title: "하루 네 번,\n말씀이 찾아가요", text: "아침에만 소리가 나요.\n시간은 언제든 바꿀 수 있어요."),
    ]
    private var last: Bool { page == leaves.count - 1 }
    /// 첫 장의 밝은 바닥 위에서는 다크에서도 짙은 색을 씁니다.
    private var dot: Color { page == 0 ? Color(hex: 0x40322F) : Ink.ink }

    var body: some View {
        TabView(selection: $page) {
            ForEach(leaves.indices, id: \.self) { i in leaf(i).tag(i) }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            if revisit || !last {
                Button(revisit ? "닫기" : "건너뛰기") { if revisit { done() } else { go(leaves.count - 1) } }
                    .font(.footnote).foregroundStyle(Ink.sub).frame(minWidth: 44, minHeight: 44).padding(.trailing, 28)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .overlay(alignment: .bottom) { controls }
        .background(Ink.canvas)
        .onAppear {
            #if DEBUG
            if Demo.screen.hasPrefix("welcome"), let n = Int(Demo.screen.dropFirst(7)) { page = min(max(n - 1, 0), leaves.count - 1) }
            #endif
            // 시작 화면에서 이미 연 문은 열린 채로 둡니다.
            open = 1
        }
    }

    @ViewBuilder private func leaf(_ i: Int) -> some View {
        if i == 0 { DoorHero(open: open).ignoresSafeArea() } else {
            let l = leaves[i]
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        art(i).frame(maxWidth: .infinity, minHeight: geo.size.height * (type.isAccessibilitySize ? 0.28 : 0.46), alignment: .bottomLeading)
                            .padding(.bottom, 48)
                        Text(l.title).font(.custom("GowunBatang-Regular", size: 24, relativeTo: .title)).lineSpacing(5).foregroundStyle(Ink.ink)
                            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                        Text(l.text).font(.footnote).lineSpacing(4).foregroundStyle(Ink.sub).padding(.top, 14)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, geo.size.width >= 600 ? 72 : 36).padding(.bottom, 190)
                }
                .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
                .background { SarakPage(hour: l.hour, lift: i == leaves.count - 1 ? 60 : 150) }
            }
            .ignoresSafeArea()
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    ForEach(leaves.indices, id: \.self) { i in
                        Circle().fill(dot.opacity(i == page ? 1 : 0.22)).frame(width: 5, height: 5)
                    }
                }
                .accessibilityElement().accessibilityLabel("\(leaves.count)장 중 \(page + 1)장")
                Spacer()
                if !last {
                    Button { next() } label: {
                        TurnMark()
                    }
                    .buttonStyle(.plain).accessibilityLabel("다음")
                }
            }
            .frame(minHeight: 52)
            if last {
                Button(revisit ? "닫기" : "말씀 알림 받기") { next() }.buttonStyle(SarakButtonStyle()).disabled(asking).frame(maxWidth: 420)
                if !revisit {
                    Button("알림 없이 시작하기") { done() }.font(.footnote).foregroundStyle(Ink.sub).frame(minHeight: 44).disabled(asking)
                }
            }
        }
        .padding(.horizontal, 36).padding(.bottom, last && !revisit ? 0 : 20)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func go(_ n: Int) { if still { page = n } else { withAnimation(.easeInOut(duration: 0.36)) { page = n } } }
    private func next() {
        if !last { go(page + 1); return }
        if revisit { done(); return }
        asking = true
        Task { var s = WordAlerts.load(); s.enabled = await WordAlerts.request(); WordAlerts.save(s); asking = false; done() }
    }

    // MARK: 장마다 하나만 놓습니다. 앱에서 실제로 만나는 부품입니다.

    @ViewBuilder private func art(_ i: Int) -> some View {
        Group {
            switch i {
            case 1:
                let r = Reading.path(WordPath.mark.day(1))
                VStack(alignment: .leading, spacing: 8) {
                    Text("오늘 읽을 본문").font(.footnote).foregroundStyle(Ink.sub)
                    Text(r.title).font(SarakFont.serif(18)).foregroundStyle(Ink.ink)
                    Rectangle().fill(Ink.ink.opacity(0.2)).frame(width: 40, height: 1).padding(.top, 8)
                }
            case 2:
                HStack(alignment: .top, spacing: 14) {
                    Ribbon().fill(SarakHour.morning.ribbon).frame(width: 12, height: 22).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("안심하라 내니 두려워하지 말라").font(SarakFont.serif(18)).foregroundStyle(Ink.ink)
                        Text("마가복음 6:50").font(.footnote).foregroundStyle(Ink.sub)
                    }
                }
            case 3:
                HStack(spacing: -10) {
                    ForEach(Array([SarakHour.morning, .noon, .night].enumerated()), id: \.offset) { n, h in
                        Text(["엄마", "나", "동생"][n]).font(.system(size: 13)).foregroundStyle(Ink.ink)
                            .frame(width: 52, height: 52).background(h.page, in: Circle())
                            .overlay(Circle().strokeBorder(SarakHour.rest.page, lineWidth: 2))
                    }
                }
            default:
                HStack(alignment: .top, spacing: 0) {
                    ForEach(WordAlerts.Slot.defaults) { s in
                        VStack(alignment: .leading, spacing: 10) {
                            HourChip(hour: s.hour)
                            Text(s.hour.name).font(.footnote).foregroundStyle(Ink.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 300)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityHidden(true)
    }
}
