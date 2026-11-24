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
    @AppStorage("blockedUIDs") private var blockedRaw = ""
    @Environment(\.openURL) private var openURL

    private var blocked: Set<String> { Set(blockedRaw.split(separator: ",").map(String.init)) }

    private var selected: SarakGroup? {
        session.groups.first { $0.id == selectedId } ?? session.groups.first { $0.id == store.activeGroupId } ?? session.groups.first
    }

    var body: some View {
        Group {
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
                .padding(.horizontal, 32).padding(.top, 8).padding(.bottom, 24)
            }
            .background(SarakColor.surface)
            .navigationTitle("함께").navigationBarTitleDisplayMode(.inline)
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
                Text("함께 읽으면 더 멀리 갑니다").font(.footnote).foregroundStyle(SarakColor.inkMuted)
            }
            Spacer()
            if let g = selected, session.isSignedIn {
                Button { inviteGroup = g } label: {
                    Label("초대", systemImage: "person.badge.plus").font(.footnote.weight(.medium))
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
                    Image(systemName: "plus").font(.footnote.weight(.medium)).foregroundStyle(SarakColor.inkMuted)
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
            return a.name < b.name   // 순위를 매기지 않습니다
        }
        let done = members.filter(\.completedToday).count
        let total = max(members.count, 1)
        let isCreator = g.createdBy == session.uid
        let isActive = store.activeGroupId == g.id

        HeroCard {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Ink.ink.opacity(0.12), lineWidth: 5)
                    Circle().trim(from: 0, to: Double(done) / Double(total))
                        .stroke(Ink.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(done)/\(members.count)").font(SarakFont.serif(18))
                }
                .frame(width: 84, height: 84)
                .accessibilityElement().accessibilityLabel("\(members.count)명 중 \(done)명 완료")
                VStack(alignment: .leading, spacing: 6) {
                    Text("오늘 함께 읽은 사람").font(.footnote).foregroundStyle(Ink.sub)
                    Text(done == 0 ? "첫 번째로 읽어볼까요?" : "\(done)명이 읽었어요").font(SarakFont.serif(18))
                    if g.hasSchedule {
                        Text("\(g.rangeName) · Day \(g.todayDay)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.ink)
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

        HStack(spacing: 10) {
            Button { inviteGroup = g } label: { Label("초대하기", systemImage: "person.badge.plus") }.buttonStyle(SecondaryButtonStyle())
            Button(role: .destructive) { confirmLeave = g } label: { Text("그룹 나가기").foregroundStyle(SarakColor.danger) }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func planCard(_ g: SarakGroup, isCreator: Bool, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("그룹 플랜").font(.subheadline.weight(.medium)).foregroundStyle(SarakColor.ink)
                Spacer()
                if isCreator && g.hasSchedule { Button("수정") { editGroup = g }.font(.footnote.weight(.medium)).foregroundStyle(SarakColor.mintInk) }
            }
            if g.hasSchedule {
                Text("\(g.rangeName) · 총 \(g.totalDays)일 · 하루 약 \(g.minutesPerDay)분").font(.footnote).foregroundStyle(SarakColor.inkMuted)
                if isActive {
                    Label("지금 이 플랜으로 읽는 중", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.medium)).foregroundStyle(SarakColor.mintInk)
                        .padding(.horizontal, 12).frame(height: 32).background(SarakColor.mintSoft, in: Capsule())
                } else {
                    Button { activate(g) } label: { Label("이 플랜으로 함께 읽기", systemImage: "book.pages") }.buttonStyle(PrimaryButtonStyle())
                }
            } else if isCreator {
                Text("아직 플랜이 없어요. 플랜을 정하면 멤버 모두에게 적용돼요.").font(.footnote).foregroundStyle(SarakColor.inkMuted)
                Button("플랜 정하기") { editGroup = g }.buttonStyle(PrimaryButtonStyle())
            } else {
                Text("그룹을 만든 분이 플랜을 정하면 자동으로 적용돼요.").font(.footnote).foregroundStyle(SarakColor.inkMuted)
            }
        }
        .card()
        .onAppear { syncIfActive(g) }
        .onChange(of: g) { _, new in syncIfActive(new) }
    }

    private func memberRow(_ m: MemberProgress, index: Int, group: SarakGroup) -> some View {
        let me = m.uid == session.uid
        let isBlocked = blocked.contains(m.uid)
        let status: String = {
            if m.completedToday { return "오늘 불을 켰어요" }
            let gap = group.todayDay - m.currentDay
            return gap > 1 ? "이어서 읽는 중" : "아직 조용해요"
        }()
        return HStack(spacing: 12) {
            AvatarView(name: m.name, index: index)
            VStack(alignment: .leading, spacing: 2) {
                Text(me ? "나 · \(m.name)" : m.name).font(.subheadline.weight(.medium)).foregroundStyle(SarakColor.ink)
                if isBlocked {
                    Text("숨긴 멤버").font(.footnote).foregroundStyle(SarakColor.inkFaint)
                } else if let c = m.todayComment, !c.isEmpty, m.completedToday {
                    Text(c).font(.footnote).foregroundStyle(SarakColor.inkMuted).lineLimit(2)
                } else {
                    Text(status).font(.footnote).foregroundStyle(SarakColor.inkMuted)
                }
            }
            Spacer(minLength: 8)
            if m.completedToday {
                Text("완료").font(.system(size: 12, weight: .semibold)).foregroundStyle(SarakColor.mintInk)
                    .padding(.horizontal, 10).frame(height: 26).background(SarakColor.mintSoft, in: Capsule())
            } else if !me && !isBlocked {
                if cheered.contains("\(group.id)-\(m.uid)") {
                    Text("응원 보냄").font(.system(size: 12, weight: .semibold)).foregroundStyle(SarakColor.inkMuted)
                        .padding(.horizontal, 12).frame(height: 32).background(SarakColor.sunken, in: Capsule())
                } else {
                    Button { cheer(m, group) } label: {
                        Label("응원하기", systemImage: "hands.clap").font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12).frame(height: 32)
                            .foregroundStyle(SarakColor.primaryFill)
                            .overlay(Capsule().stroke(SarakColor.primaryFill))
                    }
                }
            }
            if !me {
                Menu {
                    Button { report(m, group) } label: { Label("신고하기", systemImage: "exclamationmark.bubble") }
                    if isBlocked {
                        Button { setBlocked(m.uid, false) } label: { Label("숨김 해제", systemImage: "eye") }
                    } else {
                        Button(role: .destructive) { setBlocked(m.uid, true) } label: { Label("이 사람 숨기기", systemImage: "eye.slash") }
                    }
                } label: {
                    Image(systemName: "ellipsis").font(.subheadline.weight(.medium)).foregroundStyle(SarakColor.inkFaint)
                        .frame(width: 32, height: 44)
                }
                .accessibilityLabel("\(m.name) 더보기")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func setBlocked(_ uid: String, _ on: Bool) {
        var b = blocked
        if on { b.insert(uid) } else { b.remove(uid) }
        blockedRaw = b.sorted().joined(separator: ",")
    }

    /// 신고: 운영자 이메일로 그룹·사용자 정보가 담긴 메일을 엽니다. 신고와 동시에 숨김 처리.
    private func report(_ m: MemberProgress, _ g: SarakGroup) {
        let body = "신고 사유를 적어 주세요:\n\n\n---\n그룹: \(g.name) (\(g.id))\n대상: \(m.name) (\(m.uid))\n내용: \(m.todayComment ?? "")"
        var c = URLComponents()
        c.scheme = "mailto"; c.path = AppLinks.contactEmail
        c.queryItems = [URLQueryItem(name: "subject", value: "[사락] 부적절한 내용 신고"), URLQueryItem(name: "body", value: body)]
        setBlocked(m.uid, true)
        if let url = c.url { openURL(url) }
        message = "신고가 접수되도록 메일 앱을 열었어요. 이 멤버의 글은 숨겨졌습니다."
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
                        Toggle("오늘을 Day 1로 다시 시작", isOn: $restart).font(.subheadline.weight(.medium)).tint(SarakColor.mintInk)
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
                    .font(.system(size: 30, weight: .semibold)).tracking(8)
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
                            Text("\(group.name) · 초대코드").font(.footnote.weight(.medium)).foregroundStyle(SarakColor.inkMuted)
                            Text(group.inviteCode).font(.system(size: 36, weight: .semibold)).tracking(6).foregroundStyle(SarakColor.primaryFill)
                                .textSelection(.enabled)
                            Button {
                                UIPasteboard.general.string = group.inviteCode
                                copied = true
                            } label: {
                                Label(copied ? "복사했어요" : "코드 복사", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .font(.footnote.weight(.medium)).padding(.horizontal, 14).frame(height: 36)
                                    .foregroundStyle(SarakColor.ink)
                                    .background(SarakColor.raised, in: Capsule()).overlay(Capsule().stroke(SarakColor.line))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .card()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("이렇게 보내져요").font(.footnote.weight(.medium)).foregroundStyle(SarakColor.ink)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                HourChip(hour: .now)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode == 0 ? "\(session.displayName)님이 함께 읽자고 초대했어요" : "오늘 말씀 같이 읽어요")
                                        .font(.subheadline.weight(.medium)).foregroundStyle(Ink.ink)
                                    Text(mode == 0 ? "\(group.name) · \(group.memberUids.count)명이 읽는 중" : (store.plan?.day(store.currentDay) ?? today)?.displayRange ?? "")
                                        .font(.system(size: 12)).foregroundStyle(Ink.sub)
                                }
                            }
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(SarakHour.now.page)
                            Text(message).font(.footnote).foregroundStyle(SarakColor.inkMuted)
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
    @State private var apple = AppleSignIn()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoorLogo(size: 48)
            Text(title).font(.custom("GowunBatang-Regular", size: 20, relativeTo: .title2)).foregroundStyle(Ink.ink).padding(.top, 20)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.footnote).foregroundStyle(Ink.sub).padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 12) {
                button("Apple로 로그인", fg: scheme == .dark ? .black : .white, bg: scheme == .dark ? .white : .black) {
                    Image(systemName: "apple.logo").font(.system(size: 19))
                } action: {
                    apple.start { session.prepareAppleRequest($0) } done: { r in
                        Task { await run { try await session.completeApple(r) } }
                    }
                }
                button("Google로 로그인", fg: Color(hex: 0x1F1F1F), bg: .white, border: scheme == .dark ? .clear : Color(hex: 0x747775)) {
                    GoogleMark().frame(width: 18, height: 18)
                } action: { Task { await run { try await session.signInWithGoogle() } } }
            }
            .padding(.top, 28)
            if let error { Text(error).font(.footnote).foregroundStyle(Ink.danger).padding(.top, 12) }
        }
        .padding(24).padding(.bottom, 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { SarakPage(hour: .now, lift: 52) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    /// 두 버튼은 글자, 높이, 모서리, 그림 자리가 같습니다.
    private func button<I: View>(_ text: String, fg: Color, bg: Color, border: Color = .clear, @ViewBuilder icon: () -> I, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) { icon().frame(width: 22, height: 22); Text(text).font(.subheadline.weight(.medium)).lineLimit(1) }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1).padding(.horizontal, 16)
                .foregroundStyle(fg).frame(maxWidth: .infinity, minHeight: 50)
                .background(bg, in: Capsule()).overlay(Capsule().strokeBorder(border))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    private func run(_ f: () async throws -> Void) async {
        do { try await f() } catch { self.error = error.localizedDescription }
    }
}

/// 글자 크기를 Google 버튼과 맞추려고 Apple 로그인 창을 직접 엽니다.
final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var done: ((Result<ASAuthorization, Error>) -> Void)?
    private var controller: ASAuthorizationController?
    func start(_ prepare: (ASAuthorizationAppleIDRequest) -> Void, done: @escaping (Result<ASAuthorization, Error>) -> Void) {
        let r = ASAuthorizationAppleIDProvider().createRequest()
        prepare(r)
        self.done = done
        let c = ASAuthorizationController(authorizationRequests: [r])
        c.delegate = self; c.presentationContextProvider = self
        controller = c
        c.performRequests()
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization a: ASAuthorization) { done?(.success(a)) }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError e: Error) { done?(.failure(e)) }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

struct GoogleMark: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, t = w * 0.2, c = CGPoint(x: w / 2, y: w / 2), r = (w - t) / 2
            func arc(_ a: Double, _ b: Double, _ hex: UInt32) {
                var p = Path(); p.addArc(center: c, radius: r, startAngle: .degrees(a), endAngle: .degrees(b), clockwise: false)
                ctx.stroke(p, with: .color(Color(hex: hex)), lineWidth: t)
            }
            arc(0, 50, 0x4285F4); arc(50, 145, 0x34A853); arc(145, 210, 0xFBBC05); arc(210, 318, 0xEA4335)
            ctx.fill(Path(CGRect(x: w / 2, y: w / 2 - t / 2, width: w / 2, height: t)), with: .color(Color(hex: 0x4285F4)))
        }
        .accessibilityHidden(true)
    }
}
