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

    private var reading: Reading {
        .today(store, path)
    }
    private var readToday: Bool { store.plan != nil && !store.isFinished ? store.readToday : path.readToday }

    var body: some View {
        let a = path.today.alert(hour)
        NavigationStack {
            RoomScreen(hour: hour, date: Date().koreanFullDate, label: hour.alertTitle,
                       verse: a.text.versed(12), source: a.reference) {
                HStack(spacing: 0) {
                    tool("person.2", "함께") { showGroup = true }
                    tool("gearshape", "설정") { showSettings = true }
                }
                .padding(.trailing, -12)
            } action: {
                Button { openReading() } label: { todayReading }.buttonStyle(.plain)
                    .accessibilityLabel("\(readingLabel), \(reading.title), \(buttonTitle)")
            } reading: {
                if let model {
                    VStack(spacing: 8) {
                        HStack { Text(model.reading.title).font(SarakFont.serif(17)).foregroundStyle(Ink.ink); Spacer(); ReaderTools() }
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

    /// 무엇을, 얼마나 읽는지 보여 주고 귀퉁이의 버튼으로 넘깁니다.
    private var todayReading: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(readingLabel).font(.footnote).foregroundStyle(Ink.sub)
                Text(reading.title).font(.custom("GowunBatang-Regular", size: 18, relativeTo: .title3)).foregroundStyle(Ink.ink)
                    .multilineTextAlignment(.leading)
                Text(readToday ? "다시 읽기" : reading.minutes.map { "\(buttonTitle), 약 \($0)분" } ?? buttonTitle).font(.footnote).foregroundStyle(Ink.sub)
            }
            Spacer(minLength: 12)
            TurnMark()
        }
        .contentShape(Rectangle())
    }
    private var readingLabel: String { readToday ? "오늘 읽은 본문" : path.isBack ? "이어서 읽을 본문" : "오늘 읽을 본문" }
    private var buttonTitle: String { readToday ? "다시 읽기" : path.isBack ? "이어서 읽기" : "본문 읽기" }
    private func tool(_ icon: String, _ label: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) { Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Ink.ink).frame(width: 44, height: 44) }.accessibilityLabel(label)
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
