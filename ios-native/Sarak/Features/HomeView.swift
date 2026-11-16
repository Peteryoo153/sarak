import SwiftUI

struct HomeView: View {
    @Binding var tab: AppTab
    @Environment(PlanStore.self) private var store
    @Environment(Session.self) private var session
    @State private var reading: DayPlan?
    @State private var showSetup = false
    @State private var confirmCancel = false
    @AppStorage("seenCheerIDs") private var seenCheerIDs = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    cheerBanner
                    if let plan = store.plan { planHero(plan) } else { emptyHero }
                    weekCard
                    groupCard
                    if store.plan != nil { planMenu }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(SarakColor.surface)
            .refreshable { store.reload() }
            .onAppear { store.reload() }
            .fullScreenCover(item: $reading) { day in
                ReadingView(day: day)
            }
            .sheet(isPresented: $showSetup) { PlanSetupView() }
            .confirmationDialog("플랜을 그만둘까요?", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("플랜과 진도 기록 삭제", role: .destructive) { store.clearActivePlan() }
            } message: {
                Text("지금 플랜과 이 플랜의 모든 진도 기록이 지워집니다.")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().koreanFullDate).font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                Text("오늘도 말씀과 함께").font(SarakFont.title1).foregroundStyle(SarakColor.ink)
            }
            Spacer()
            if store.streak > 0 {
                Label("\(store.streak)일 연속", systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SarakColor.streak)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(SarakColor.raised, in: Capsule())
                    .overlay(Capsule().stroke(SarakColor.line))
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder private var cheerBanner: some View {
        let seen = Set(seenCheerIDs.split(separator: ",").map(String.init))
        let fresh = session.cheers.filter { !seen.contains($0.id) }
        if let c = fresh.first {
            HStack(spacing: 12) {
                Image(systemName: "hands.clap.fill").font(.system(size: 18)).foregroundStyle(SarakColor.mintInk)
                    .frame(width: 40, height: 40).background(SarakColor.mintSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(fresh.count > 1 ? "\(c.fromName)님 외 \(fresh.count - 1)명이 응원을 보냈어요" : "\(c.fromName)님이 응원을 보냈어요")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(SarakColor.ink)
                    Text("\(c.groupName) · 오늘 말씀 함께 읽어요").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                }
                Spacer(minLength: 0)
                Button {
                    seenCheerIDs = (seen.union(fresh.map(\.id))).joined(separator: ",")
                } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(SarakColor.inkFaint)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("응원 알림 닫기")
            }
            .card(padding: 14)
        }
    }

    // MARK: Hero

    private func planHero(_ plan: ReadingPlan) -> some View {
        let dayNum = store.currentDay
        let today = plan.day(dayNum)
        let doneToday = store.readToday
        let behind = plan.scheduledDay() - dayNum

        return HeroCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    DayBadge(text: "Day \(dayNum) · \(plan.groupName ?? plan.rangeName)")
                    Spacer()
                    if let today { Text("약 \(today.estimatedMinutes)분").font(.system(size: 13)).foregroundStyle(SarakColor.onIndigoMuted) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if store.isFinished {
                        Text("완주했어요!").font(SarakFont.serif(30, bold: true))
                        Text("\(plan.rangeName) 통독을 마쳤습니다. 수고하셨어요.").font(.system(size: 14)).foregroundStyle(SarakColor.onIndigoMuted)
                    } else if doneToday {
                        Text("오늘 읽기 완료").font(SarakFont.serif(30, bold: true))
                        Text("다음은 \(today?.displayRange ?? "")").font(.system(size: 14)).foregroundStyle(SarakColor.onIndigoMuted)
                    } else {
                        Text(today?.displayRange ?? "").font(SarakFont.serif(30, bold: true))
                            .fixedSize(horizontal: false, vertical: true)
                        if behind > 1 {
                            Text("계획보다 \(behind - 1)일 늦어요 · 이어서 읽으면 돼요")
                                .font(.system(size: 14)).foregroundStyle(SarakColor.onIndigoMuted)
                        }
                    }
                }
                VStack(spacing: 8) {
                    ProgressBar(value: store.progress)
                    HStack {
                        Text("전체 진행 \(Int((store.progress * 100).rounded()))%")
                        Spacer()
                        Text("\(max(plan.totalDays - store.completed.count, 0))일 남음")
                    }
                    .font(.system(size: 12)).foregroundStyle(SarakColor.onIndigoMuted)
                }
                if !store.isFinished, let today {
                    Button { reading = today } label: {
                        Label(doneToday ? "다음 날 말씀 미리 읽기" : "오늘 말씀 읽기", systemImage: "book.pages.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(fill: doneToday ? Color.white.opacity(0.12) : SarakColor.mint,
                                                    foreground: doneToday ? .white : SarakColor.indigo))
                } else if store.isFinished {
                    Button("새 플랜 시작하기") { showSetup = true }
                        .buttonStyle(PrimaryButtonStyle(fill: SarakColor.mint, foreground: SarakColor.indigo))
                }
            }
        }
    }

    private var emptyHero: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: 16) {
                DayBadge(text: "시작하기")
                VStack(alignment: .leading, spacing: 6) {
                    Text("나만의 통독 플랜을\n만들어 보세요").font(SarakFont.serif(28, bold: true))
                    Text("읽을 범위와 기간만 고르면 매일 읽을 분량을 나눠 드려요.")
                        .font(.system(size: 14)).foregroundStyle(SarakColor.onIndigoMuted)
                }
                Button { showSetup = true } label: { Label("통독 플랜 만들기", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle(fill: SarakColor.mint, foreground: SarakColor.indigo))
                Button { tab = .together } label: {
                    Text("그룹 플랜으로 함께 읽기").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    // MARK: Week

    private var weekCard: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = (cal.component(.weekday, from: today) + 5) % 7 // 월=0
        let monday = cal.date(byAdding: .day, value: -weekday, to: today)!
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday)! }
        let labels = ["월", "화", "수", "목", "금", "토", "일"]

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("이번 주").font(.system(size: 17, weight: .bold)).foregroundStyle(SarakColor.ink)
                Spacer()
                Button("달력 보기") { tab = .calendar }.font(.system(size: 13, weight: .semibold)).foregroundStyle(SarakColor.mintInk)
            }
            HStack(spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    let done = !store.entries(on: d).isEmpty
                    let isToday = d == today
                    let future = d > today
                    VStack(spacing: 6) {
                        Text(labels[i]).font(SarakFont.micro).foregroundStyle(isToday ? SarakColor.primaryFill : SarakColor.inkMuted)
                        VStack(spacing: 1) {
                            Text("\(cal.component(.day, from: d))").font(.system(size: 14, weight: isToday || done ? .heavy : .semibold))
                            if done { Image(systemName: "checkmark").font(.system(size: 9, weight: .black)) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(done ? SarakColor.mintInk : isToday ? SarakColor.primaryFill : future ? SarakColor.inkFaint : SarakColor.inkMuted)
                        .background(done ? SarakColor.mintSoft : future || isToday ? Color.clear : SarakColor.sunken,
                                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                        .overlay {
                            if isToday { RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).stroke(SarakColor.primaryFill, lineWidth: 2) }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(labels[i])요일 \(cal.component(.day, from: d))일\(done ? ", 읽음" : "")")
                }
            }
        }
        .card()
    }

    // MARK: Group

    @ViewBuilder private var groupCard: some View {
        if let g = session.groups.first(where: { $0.id == store.activeGroupId }) ?? session.groups.first {
            let members = session.progress[g.id] ?? []
            let done = members.filter(\.completedToday).count
            Button { tab = .together } label: {
                HStack(spacing: 14) {
                    HStack(spacing: -10) {
                        ForEach(Array(members.prefix(3).enumerated()), id: \.offset) { i, m in
                            AvatarView(name: m.name, index: i, size: 36).overlay(Circle().stroke(SarakColor.raised, lineWidth: 2))
                        }
                        if members.count > 3 {
                            Text("+\(members.count - 3)").font(.system(size: 12, weight: .bold)).foregroundStyle(SarakColor.inkMuted)
                                .frame(width: 36, height: 36).background(SarakColor.sunken, in: Circle())
                                .overlay(Circle().stroke(SarakColor.raised, lineWidth: 2))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.name).font(.system(size: 15, weight: .bold)).foregroundStyle(SarakColor.ink)
                        Text("오늘 \(max(members.count, g.memberUids.count))명 중 \(done)명 완료").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(SarakColor.inkFaint)
                }
            }
            .buttonStyle(.plain)
            .card(padding: 16)
        }
    }

    private var planMenu: some View {
        HStack(spacing: 10) {
            Button { showSetup = true } label: { Label("플랜 바꾸기", systemImage: "slider.horizontal.3") }
                .buttonStyle(SecondaryButtonStyle())
            Button(role: .destructive) { confirmCancel = true } label: { Label("플랜 그만두기", systemImage: "xmark.circle") }
                .buttonStyle(SecondaryButtonStyle())
        }
    }
}

struct ProgressBar: View {
    var value: Double
    var track: Color = .white.opacity(0.14)
    var fill: Color = SarakColor.mint
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill).frame(width: max(geo.size.width * value, value > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("진행률 \(Int(value * 100))퍼센트")
    }
}
