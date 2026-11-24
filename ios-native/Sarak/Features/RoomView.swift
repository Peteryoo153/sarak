import SwiftUI

/// 골방: 지금 찾아온 말씀 하나와 오늘의 본문
struct RoomView: View {
    @Environment(PathStore.self) private var path
    @Environment(PlanStore.self) private var store
    @Environment(Session.self) private var session
    @Environment(\.scenePhase) private var phase
    @State private var hour = SarakHour.now
    @State private var model: ReaderModel?
    @State private var open = false
    @State private var showGroup = false
    @State private var showSettings = false
    @State private var showDone = false

    /// 통독 플랜을 쓰던 분은 그 플랜을, 아니면 말씀길을 읽습니다.
    private var reading: Reading {
        if let plan = store.plan, !store.isFinished, let d = plan.day(store.currentDay) { return .plan(d) }
        return .path(path.today)
    }
    private var readToday: Bool { store.plan != nil && !store.isFinished ? store.readToday : path.readToday }

    var body: some View {
        let a = path.today.alert(hour)
        NavigationStack {
            RoomScreen(hour: hour, greeting: path.isBack ? "책갈피는 그 자리에 있어요" : hour.greeting, date: Date().koreanFullDate,
                       verse: a.text.versed(12), source: a.reference) {
                HStack(spacing: 0) {
                    tool("person.2", "함께") { showGroup = true }
                    tool("gearshape", "설정") { showSettings = true }
                }
                .padding(.trailing, -12)
            } action: {
                Button(buttonTitle) { openReading() }.buttonStyle(SarakButtonStyle())
                Text(caption).font(.footnote).foregroundStyle(Ink.sub).multilineTextAlignment(.center)
            } reading: {
                if let model {
                    VStack(spacing: 8) {
                        HStack { Text(model.reading.title).font(.headline).foregroundStyle(Ink.ink); Spacer(); ReaderTools(model: model) }
                            .padding(.top, 12)
                        PassageBody(model: model) { showDone = true }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showGroup) { GroupView() }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
        }
        .onAppear { refresh() }
        .onChange(of: phase) { _, p in if p == .active { refresh() } }
        .onChange(of: reading) { _, r in model?.show(r) }
        .onChange(of: session.pendingInviteCode) { _, c in if c != nil { showGroup = true } }
        .fullScreenCover(isPresented: $open) { if let model { ReadingView(model: model) } }
        .fullScreenCover(isPresented: $showDone) { if let model { DoneView(model: model) } }
        #if DEBUG
        .task {
            switch Demo.screen {
            case "read": model?.selected = ["41-4-31"]; open = true
            case "done": showDone = true
            case "group": showGroup = true
            case "settings": showSettings = true
            default: break
            }
        }
        #endif
    }

    private var buttonTitle: String {
        if readToday { return "오늘의 본문 다시 펼치기" }
        if path.isBack { return "이어서 펼치기" }
        return "오늘의 본문 \(reading.minutes ?? 5)분쯤 읽기"
    }
    private var caption: String {
        if readToday { return "오늘의 종이는 이미 넘겼어요." }
        if case .plan = reading.kind { return reading.title }
        if path.isBack { return "오늘 5분부터 다시 펼쳐요." }
        return "하루 5분, 25일이면 마가복음 한 권."
    }
    private func tool(_ icon: String, _ label: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) { Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Ink.ink).frame(width: 44, height: 44) }.accessibilityLabel(label)
    }
    private func refresh() {
        hour = .now
        path.reload(); store.reload()
        if let model { model.show(reading) } else { model = ReaderModel(reading) }
        PhoneLink.shared.send(day: path.today.day)
        let (d, done) = (path.nextDay, path.readToday)
        Task { await WordAlerts.reschedule(WordAlerts.load(), from: done ? max(d - 1, 1) : d, readToday: done) }
    }
    private func openReading() {
        if let model { model.show(reading) } else { model = ReaderModel(reading) }
        open = true
    }
}
