import SwiftUI
import AuthenticationServices

struct GroupView: View {
    @Environment(Session.self) private var session
    @Environment(PlanStore.self) private var store
    @State private var selectedId: String?
    @State private var showCreate = false
    @State private var editGroup: SarakGroup?
    @State private var showJoin = false
    @State private var inviteGroup: SarakGroup?
    @State private var confirmLeave: SarakGroup?
    @State private var cheered: Set<String> = []
    @State private var message: String?

    private var selected: SarakGroup? {
        session.groups.first { $0.id == selectedId } ?? session.groups.first { $0.id == store.activeGroupId } ?? session.groups.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if !session.isSignedIn {
                        LoginPrompt(title: "함께 읽으려면 로그인이 필요해요", subtitle: "그룹을 만들거나 초대코드로 참여해 보세요.")
                    } else if !session.groupsLoaded {
                        ProgressView().padding(40)
                    } else if session.groups.isEmpty {
                        emptyState
                    } else {
                        groupChips
                        if let g = selected { groupDetail(g) }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .background(SarakColor.surface)
            .sheet(isPresented: $showCreate) { GroupEditorView(group: nil) { selectedId = $0.id } }
            .sheet(item: $editGroup) { g in GroupEditorView(group: g) { _ in } }
            .sheet(isPresented: $showJoin) { JoinGroupSheet { selectedId = $0.id } }
            .sheet(item: $inviteGroup) { g in InviteSheet(group: g) }
            .confirmationDialog("그룹에서 나갈까요?", isPresented: Binding(get: { confirmLeave != nil }, set: { if !$0 { confirmLeave = nil } }),
                                titleVisibility: .visible, presenting: confirmLeave) { g in
                Button("나가기", role: .destructive) { leave(g) }
            } message: { _ in Text("이 그룹의 내 진도 기록이 지워져요.") }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("확인") {} }
            .onChange(of: session.pendingInviteCode) { _, code in if code != nil, session.isSignedIn { showJoin = true } }
            .onAppear { if session.pendingInviteCode != nil, session.isSignedIn { showJoin = true } }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("함께").font(SarakFont.title1).foregroundStyle(SarakColor.ink)
                Text("함께 읽으면 더 멀리 갑니다").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
            }
            Spacer()
            if let g = selected, session.isSignedIn {
                Button { inviteGroup = g } label: {
                    Label("초대", systemImage: "person.badge.plus").font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14).frame(height: 36)
                        .foregroundStyle(SarakColor.ink)
                        .background(SarakColor.raised, in: Capsule()).overlay(Capsule().stroke(SarakColor.line))
                }
            }
        }
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3").font(.system(size: 34)).foregroundStyle(SarakColor.mintInk)
                .frame(width: 72, height: 72).background(SarakColor.mintSoft, in: Circle())
            VStack(spacing: 6) {
                Text("아직 함께 읽는 그룹이 없어요").font(SarakFont.title2).foregroundStyle(SarakColor.ink)
                Text("교회, 가족, 친구와 같은 플랜으로 매일 함께 읽어요.").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
            }
            Button { showCreate = true } label: { Label("새 그룹 만들기", systemImage: "plus") }.buttonStyle(PrimaryButtonStyle())
            Button { showJoin = true } label: { Label("초대코드로 참여", systemImage: "ticket") }.buttonStyle(SecondaryButtonStyle())
        }
        .card(padding: 24)
    }

    private var groupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(session.groups) { g in
                    Button(g.name) { selectedId = g.id }.buttonStyle(PillButtonStyle(selected: g.id == selected?.id))
                }
                Menu {
                    Button { showCreate = true } label: { Label("새 그룹 만들기", systemImage: "plus") }
                    Button { showJoin = true } label: { Label("초대코드로 참여", systemImage: "ticket") }
                } label: {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(SarakColor.inkMuted)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(SarakColor.inkFaint, style: StrokeStyle(lineWidth: 1, dash: [3])))
                }
                .accessibilityLabel("그룹 추가")
            }
        }
    }

    @ViewBuilder private func groupDetail(_ g: SarakGroup) -> some View {
        let members = (session.progress[g.id] ?? []).sorted { a, b in
            if a.uid == session.uid { return true }
            if b.uid == session.uid { return false }
            if a.completedToday != b.completedToday { return a.completedToday }
            return a.currentDay > b.currentDay
        }
        let done = members.filter(\.completedToday).count
        let total = max(members.count, 1)
        let isCreator = g.createdBy == session.uid
        let isActive = store.activeGroupId == g.id

        HeroCard {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.14), lineWidth: 9)
                    Circle().trim(from: 0, to: Double(done) / Double(total))
                        .stroke(SarakColor.mint, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(done)/\(members.count)").font(.system(size: 20, weight: .heavy))
                }
                .frame(width: 84, height: 84)
                .accessibilityElement().accessibilityLabel("\(members.count)명 중 \(done)명 완료")
                VStack(alignment: .leading, spacing: 6) {
                    Text("오늘 함께 읽은 사람").font(.system(size: 13)).foregroundStyle(SarakColor.onIndigoMuted)
                    Text(done == 0 ? "첫 번째로 읽어볼까요?" : "\(done)명이 읽었어요").font(.system(size: 20, weight: .heavy))
                    if g.hasSchedule {
                        Text("\(g.rangeName) · Day \(g.todayDay)").font(.system(size: 12, weight: .bold)).foregroundStyle(SarakColor.mint)
                    }
                }
            }
        }

        planCard(g, isCreator: isCreator, isActive: isActive)

        VStack(spacing: 0) {
            ForEach(Array(members.enumerated()), id: \.element.uid) { i, m in
                memberRow(m, index: i, group: g)
                if i < members.count - 1 { Divider().overlay(SarakColor.line) }
            }
        }
        .padding(.vertical, 4)
        .background(SarakColor.raised, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(SarakColor.line))

        HStack(spacing: 10) {
            Button { inviteGroup = g } label: { Label("초대하기", systemImage: "person.badge.plus") }.buttonStyle(SecondaryButtonStyle())
            Button(role: .destructive) { confirmLeave = g } label: { Text("그룹 나가기").foregroundStyle(SarakColor.danger) }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func planCard(_ g: SarakGroup, isCreator: Bool, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("그룹 플랜").font(.system(size: 17, weight: .bold)).foregroundStyle(SarakColor.ink)
                Spacer()
                if isCreator && g.hasSchedule { Button("수정") { editGroup = g }.font(.system(size: 14, weight: .semibold)).foregroundStyle(SarakColor.mintInk) }
            }
            if g.hasSchedule {
                Text("\(g.rangeName) · 총 \(g.totalDays)일 · 하루 약 \(g.minutesPerDay)분").font(.system(size: 14)).foregroundStyle(SarakColor.inkMuted)
                if isActive {
                    Label("지금 이 플랜으로 읽는 중", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(SarakColor.mintInk)
                        .padding(.horizontal, 12).frame(height: 32).background(SarakColor.mintSoft, in: Capsule())
                } else {
                    Button { activate(g) } label: { Label("이 플랜으로 함께 읽기", systemImage: "book.pages") }.buttonStyle(PrimaryButtonStyle())
                }
            } else if isCreator {
                Text("아직 플랜이 없어요. 플랜을 정하면 멤버 모두에게 적용돼요.").font(.system(size: 14)).foregroundStyle(SarakColor.inkMuted)
                Button("플랜 정하기") { editGroup = g }.buttonStyle(PrimaryButtonStyle())
            } else {
                Text("그룹을 만든 분이 플랜을 정하면 자동으로 적용돼요.").font(.system(size: 14)).foregroundStyle(SarakColor.inkMuted)
            }
        }
        .card()
        .onAppear { syncIfActive(g) }
        .onChange(of: g) { _, new in syncIfActive(new) }
    }

    private func memberRow(_ m: MemberProgress, index: Int, group: SarakGroup) -> some View {
        let me = m.uid == session.uid
        let status: String = {
            if m.completedToday { return "Day \(m.currentDay) · 오늘 읽음" }
            let gap = group.todayDay - m.currentDay
            return gap > 1 ? "Day \(m.currentDay) · 이어서 읽는 중" : "Day \(m.currentDay) · 아직 안 읽음"
        }()
        return HStack(spacing: 12) {
            AvatarView(name: m.name, index: index)
            VStack(alignment: .leading, spacing: 2) {
                Text(me ? "나 · \(m.name)" : m.name).font(.system(size: 15, weight: .bold)).foregroundStyle(SarakColor.ink)
                if let c = m.todayComment, !c.isEmpty, m.completedToday {
                    Text(c).font(.system(size: 13)).foregroundStyle(SarakColor.inkMuted).lineLimit(2)
                } else {
                    Text(status).font(.system(size: 13)).foregroundStyle(SarakColor.inkMuted)
                }
            }
            Spacer(minLength: 8)
            if m.completedToday {
                Text("완료").font(.system(size: 12, weight: .bold)).foregroundStyle(SarakColor.mintInk)
                    .padding(.horizontal, 10).frame(height: 26).background(SarakColor.mintSoft, in: Capsule())
            } else if !me {
                if cheered.contains("\(group.id)-\(m.uid)") {
                    Text("응원 보냄").font(.system(size: 12, weight: .bold)).foregroundStyle(SarakColor.inkMuted)
                        .padding(.horizontal, 12).frame(height: 32).background(SarakColor.sunken, in: Capsule())
                } else {
                    Button { cheer(m, group) } label: {
                        Label("응원하기", systemImage: "hands.clap").font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 12).frame(height: 32)
                            .foregroundStyle(SarakColor.primaryFill)
                            .overlay(Capsule().stroke(SarakColor.primaryFill))
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func activate(_ g: SarakGroup) {
        store.savePlan(g.asLocalPlan, for: PlanStore.groupSource(g.id))
        store.setActiveSource(PlanStore.groupSource(g.id))
    }

    /// 방장이 플랜을 바꾸면 활성 사용자의 로컬 캐시도 갱신
    private func syncIfActive(_ g: SarakGroup) {
        guard g.hasSchedule, store.activeGroupId == g.id else { return }
        let local = PlanStore.loadPlan(for: PlanStore.groupSource(g.id))
        if local?.schedule != g.schedule || local?.startDate != g.asLocalPlan.startDate {
            store.savePlan(g.asLocalPlan, for: PlanStore.groupSource(g.id))
            store.reload()
        }
    }

    private func cheer(_ m: MemberProgress, _ g: SarakGroup) {
        cheered.insert("\(g.id)-\(m.uid)")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            do { try await session.sendCheer(to: m, in: g) } catch {
                cheered.remove("\(g.id)-\(m.uid)")
                message = "응원을 보내지 못했어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    private func leave(_ g: SarakGroup) {
        Task {
            do {
                try await session.leaveGroup(g)
                store.clearGroupCache(g.id)
                selectedId = nil
            } catch { message = "그룹에서 나가지 못했어요: \(error.localizedDescription)" }
        }
    }
}

// MARK: - Create / edit

struct GroupEditorView: View {
    let group: SarakGroup?
    var onSaved: (SarakGroup) -> Void
    @Environment(Session.self) private var session
    @Environment(PlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var preset = RangePreset.all[0]
    @State private var days = 90
    @State private var restart = false
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if group == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "그룹 이름")
                            TextField("예: 청년부 90일 통독", text: $name)
                                .font(.system(size: 16))
                                .padding(14)
                                .background(SarakColor.raised, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(SarakColor.line))
                        }
                    }
                    PlanPicker(preset: $preset, days: $days)
                    if group?.hasSchedule == true {
                        Toggle("오늘을 Day 1로 다시 시작", isOn: $restart).font(.system(size: 15, weight: .semibold)).tint(SarakColor.mintInk)
                    }
                    Text(group == nil ? "이 플랜은 그룹원 모두가 함께 따라요. 그룹을 만든 뒤 초대 링크를 보내 보세요."
                                      : "플랜을 바꿔도 멤버들의 완료 기록은 남아요. 각 Day의 본문만 새 플랜을 따릅니다.")
                        .font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                    if let error { Text(error).font(SarakFont.caption).foregroundStyle(SarakColor.danger) }
                }
                .padding(20)
            }
            .background(SarakColor.surface)
            .safeAreaInset(edge: .bottom) {
                Button { save() } label: {
                    if saving { ProgressView().tint(SarakColor.onPrimary) } else { Text(group == nil ? "그룹 만들기" : "플랜 저장") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(saving || (group == nil && name.trimmingCharacters(in: .whitespaces).isEmpty))
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(SarakColor.surface)
            }
            .navigationTitle(group == nil ? "새 그룹" : "그룹 플랜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .onAppear {
                if let g = group {
                    preset = RangePreset.matching(start: g.startBookId, end: g.endBookId)
                    if g.hasSchedule { days = PlanPicker.dayOptions.min { abs($0 - g.totalDays) < abs($1 - g.totalDays) } ?? 90 }
                }
            }
        }
    }

    private func save() {
        saving = true; error = nil
        let schedule = ScheduleEngine.generate(startBookId: preset.startBookId, endBookId: preset.endBookId, totalDays: days)
        Task {
            do {
                if let g = group {
                    try await session.updateGroupPlan(g, preset: preset, schedule: schedule, restart: restart)
                    onSaved(g)
                } else {
                    let g = try await session.createGroup(name: name.trimmingCharacters(in: .whitespaces), preset: preset, days: days, schedule: schedule)
                    store.savePlan(g.asLocalPlan, for: PlanStore.groupSource(g.id))
                    store.setActiveSource(PlanStore.groupSource(g.id))
                    onSaved(g)
                }
                dismiss()
            } catch {
                self.error = "저장하지 못했어요: \(error.localizedDescription)"
            }
            saving = false
        }
    }
}

// MARK: - Join

struct JoinGroupSheet: View {
    var onJoined: (SarakGroup) -> Void
    @Environment(Session.self) private var session
    @Environment(PlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var joining = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("받은 초대코드 6자리를 입력하세요.").font(.system(size: 15)).foregroundStyle(SarakColor.inkMuted)
                TextField("ABC123", text: $code)
                    .font(.system(size: 30, weight: .heavy)).tracking(8)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .focused($focused)
                    .padding(.vertical, 18)
                    .background(SarakColor.raised, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(SarakColor.line))
                    .onChange(of: code) { _, v in code = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6)) }
                if let error { Text(error).font(SarakFont.caption).foregroundStyle(SarakColor.danger) }
                Button { join() } label: {
                    if joining { ProgressView().tint(SarakColor.onPrimary) } else { Text("참여하기") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(code.count != 6 || joining)
                Spacer()
            }
            .padding(20)
            .background(SarakColor.surface)
            .navigationTitle("초대코드로 참여")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .onAppear {
                if let c = session.pendingInviteCode { code = c; session.pendingInviteCode = nil } else { focused = true }
            }
        }
        .presentationDetents([.medium])
    }

    private func join() {
        joining = true; error = nil
        Task {
            do {
                let g = try await session.joinGroup(code: code)
                if g.hasSchedule {
                    store.savePlan(g.asLocalPlan, for: PlanStore.groupSource(g.id))
                    store.setActiveSource(PlanStore.groupSource(g.id))
                }
                onJoined(g)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            joining = false
        }
    }
}

// MARK: - Invite

struct InviteSheet: View {
    let group: SarakGroup
    @Environment(Session.self) private var session
    @Environment(PlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var copied = false

    private var today: DayPlan? {
        group.schedule.isEmpty ? nil : group.schedule[min(group.todayDay - 1, group.schedule.count - 1)]
    }
    private var message: String {
        if mode == 0 { return ShareService.inviteMessage(from: session.displayName, group: group, today: today) }
        let day = store.plan?.day(store.currentDay) ?? today
        return day.map { ShareService.readTogetherMessage(from: session.displayName, today: $0) } ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("", selection: $mode) {
                        Text("그룹 초대").tag(0)
                        Text("오늘 같이 읽기").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if mode == 0 {
                        VStack(spacing: 12) {
                            Text("\(group.name) · 초대코드").font(.system(size: 13, weight: .semibold)).foregroundStyle(SarakColor.inkMuted)
                            Text(group.inviteCode).font(.system(size: 36, weight: .heavy)).tracking(6).foregroundStyle(SarakColor.primaryFill)
                                .textSelection(.enabled)
                            Button {
                                UIPasteboard.general.string = group.inviteCode
                                copied = true
                            } label: {
                                Label(copied ? "복사했어요" : "코드 복사", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 13, weight: .bold)).padding(.horizontal, 14).frame(height: 36)
                                    .foregroundStyle(SarakColor.ink)
                                    .background(SarakColor.raised, in: Capsule()).overlay(Capsule().stroke(SarakColor.line))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .card()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("이렇게 보내져요").font(.system(size: 13, weight: .bold)).foregroundStyle(SarakColor.ink)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                Image("Logo").resizable().scaledToFit().frame(width: 22, height: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode == 0 ? "\(session.displayName)님이 함께 읽자고 초대했어요" : "오늘 말씀 같이 읽어요")
                                        .font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                    Text(mode == 0 ? "\(group.name) · \(group.memberUids.count)명이 읽는 중" : (store.plan?.day(store.currentDay) ?? today)?.displayRange ?? "")
                                        .font(.system(size: 12)).foregroundStyle(SarakColor.onIndigoMuted)
                                }
                            }
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(SarakColor.indigo)
                            Text(message).font(.system(size: 13)).foregroundStyle(SarakColor.inkMuted)
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(SarakColor.raised)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(SarakColor.line))
                    }
                }
                .padding(20)
            }
            .background(SarakColor.surface)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button { ShareService.share(mode == 0 ? [message, AppLinks.inviteURL(code: group.inviteCode)] : [message]) } label: {
                        Label(mode == 0 ? "초대 메시지 보내기" : "같이 읽자고 보내기", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text("카카오톡, 문자, 인스타그램 DM 등 원하는 앱으로 보낼 수 있어요").font(.system(size: 12)).foregroundStyle(SarakColor.inkMuted)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(SarakColor.surface)
            }
            .navigationTitle("함께 읽을 사람 부르기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
    }
}

// MARK: - Login

struct LoginPrompt: View {
    let title: String
    let subtitle: String
    @Environment(Session.self) private var session
    @Environment(\.colorScheme) private var scheme
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.checkmark").font(.system(size: 32)).foregroundStyle(SarakColor.mintInk)
                .frame(width: 68, height: 68).background(SarakColor.mintSoft, in: Circle())
            VStack(spacing: 4) {
                Text(title).font(SarakFont.title2).foregroundStyle(SarakColor.ink).multilineTextAlignment(.center)
                Text(subtitle).font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted).multilineTextAlignment(.center)
            }
            SignInWithAppleButton(.signIn) { req in
                session.prepareAppleRequest(req)
            } onCompletion: { result in
                Task { do { try await session.completeApple(result) } catch { self.error = error.localizedDescription } }
            }
            .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

            Button {
                Task { do { try await session.signInWithGoogle() } catch { self.error = error.localizedDescription } }
            } label: {
                HStack(spacing: 8) {
                    Text("G").font(.system(size: 18, weight: .heavy)).foregroundStyle(Color(hex: 0x4285F4))
                    Text("Google로 로그인")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            if let error { Text(error).font(SarakFont.caption).foregroundStyle(SarakColor.danger).multilineTextAlignment(.center) }
        }
        .card(padding: 24)
    }
}
