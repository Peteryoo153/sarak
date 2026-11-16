import SwiftUI

struct SettingsView: View {
    @Environment(Session.self) private var session
    @Environment(PlanStore.self) private var store
    @Environment(\.openURL) private var openURL
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var message: String?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if session.isSignedIn {
                        HStack(spacing: 14) {
                            AvatarView(name: session.displayName, size: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.displayName).font(.system(size: 17, weight: .bold)).foregroundStyle(SarakColor.ink)
                                Text(session.user?.email ?? "").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                            }
                        }
                        .padding(.vertical, 6)
                    } else {
                        LoginPrompt(title: "로그인하고 함께 읽어요", subtitle: "그룹 통독과 완주 기록을 안전하게 보관해요.")
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section("나의 기록") {
                    NavigationLink { HistoryView() } label: { row("나의 통독 기록", "trophy") }
                    NavigationLink { BookmarksView() } label: { row("북마크한 말씀", "bookmark", detail: "\(store.bookmarks.count)") }
                }

                Section("설정") {
                    NavigationLink { ReminderSettingsView() } label: { row("매일 읽기 알림", "bell") }
                    Picker(selection: $appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                    } label: { row("화면 모드", "circle.lefthalf.filled") }
                    row("성경 역본", "text.book.closed", detail: "개역개정")
                }

                Section("사역 후원 및 문의") {
                    Button { openURL(AppLinks.support) } label: { row("사역 후원하기", "heart", tint: Color(hex: 0xD6457A), external: true) }
                    Button { openURL(URL(string: "mailto:\(AppLinks.contactEmail)?subject=%5B%EC%82%AC%EB%9D%BD%5D%20%EB%AC%B8%EC%9D%98")!) } label: {
                        row("앱 제안 및 문의", "envelope", detail: AppLinks.contactEmail)
                    }
                    Button { openURL(AppLinks.maker) } label: { row("만든 사람", "person", detail: "유찬호 목사", external: true) }
                    row("버전", "info.circle", detail: version)
                }

                if session.isSignedIn {
                    Section {
                        Button("로그아웃") { session.signOut() }.foregroundStyle(SarakColor.ink)
                        Button("계정 삭제", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("사락 · 생명의 말씀이 사락 넘어갑니다").frame(maxWidth: .infinity).padding(.top, 16)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SarakColor.surface)
            .navigationTitle("더보기")
            .confirmationDialog("계정을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("계정과 모든 데이터 삭제", role: .destructive) { deleteAccount() }
            } message: { Text("그룹 참여 기록과 완주 기록이 모두 지워지고 되돌릴 수 없어요. 이 기기에 저장된 개인 플랜은 남아요.") }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("확인") {} }
            .overlay { if deleting { ProgressView().padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
        }
    }

    private func row(_ title: String, _ icon: String, detail: String? = nil, tint: Color = SarakColor.ink, external: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(tint).frame(width: 24)
            Text(title).font(.system(size: 16)).foregroundStyle(SarakColor.ink)
            Spacer()
            if let detail { Text(detail).font(.system(size: 14)).foregroundStyle(SarakColor.inkMuted).lineLimit(1) }
            if external { Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(SarakColor.inkFaint) }
        }
        .contentShape(Rectangle())
    }

    private func deleteAccount() {
        deleting = true
        Task {
            do {
                try await session.deleteAccount()
                message = "계정이 삭제되었습니다."
            } catch {
                message = error.localizedDescription
            }
            deleting = false
        }
    }
}

struct ReminderSettingsView: View {
    @AppStorage("reminderEnabled") private var enabled = false
    @AppStorage("reminderHour") private var hour = 7
    @AppStorage("reminderMinute") private var minute = 0
    @State private var denied = false

    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        } set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            hour = c.hour ?? 7; minute = c.minute ?? 0
            if enabled { ReminderService.schedule(hour: hour, minute: minute) }
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle("매일 읽기 알림", isOn: $enabled)
                    .tint(SarakColor.mintInk)
                    .onChange(of: enabled) { _, on in
                        if on {
                            Task {
                                if !(await ReminderService.requestAndSchedule(hour: hour, minute: minute)) { enabled = false; denied = true }
                            }
                        } else { ReminderService.cancel() }
                    }
                if enabled { DatePicker("알림 시간", selection: time, displayedComponents: .hourAndMinute) }
            } footer: {
                Text(denied ? "알림 권한이 꺼져 있어요. 설정 앱 > 사락사락 Bible > 알림에서 켜 주세요."
                            : "정한 시간에 매일 오늘의 말씀을 알려 드려요.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(SarakColor.surface)
        .navigationTitle("매일 읽기 알림")
    }
}

struct HistoryView: View {
    @Environment(Session.self) private var session
    @State private var records: [CompletionRecord] = []
    @State private var loaded = false

    var body: some View {
        List {
            if !session.isSignedIn {
                Text("로그인하면 완주 기록이 저장돼요.").foregroundStyle(SarakColor.inkMuted)
            } else if loaded && records.isEmpty {
                Text("아직 완주한 플랜이 없어요. 오늘 한 장부터 시작해요.").foregroundStyle(SarakColor.inkMuted)
            }
            ForEach(records) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(r.planName).font(.system(size: 16, weight: .bold)).foregroundStyle(SarakColor.ink)
                        Spacer()
                        Text("완주").font(.system(size: 12, weight: .bold)).foregroundStyle(SarakColor.mintInk)
                            .padding(.horizontal, 10).frame(height: 24).background(SarakColor.mintSoft, in: Capsule())
                    }
                    Text("\(r.range) · \(r.startDate.formatted(.dateTime.year().month().day())) ~ \(r.completedAt.formatted(.dateTime.year().month().day()))")
                        .font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(SarakColor.surface)
        .navigationTitle("나의 통독 기록")
        .task { records = await session.completionRecords(); loaded = true }
    }
}

struct BookmarksView: View {
    @Environment(PlanStore.self) private var store
    @State private var share: ShareVerses?

    var body: some View {
        List {
            if store.bookmarks.isEmpty {
                Text("읽기 화면에서 구절을 누르고 '저장'을 누르면 여기에 모여요.").foregroundStyle(SarakColor.inkMuted)
            }
            ForEach(store.bookmarks) { b in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(b.bookName) \(b.chapter):\(b.verse)").font(.system(size: 13, weight: .bold)).foregroundStyle(SarakColor.mintInk)
                    Text(b.text).font(SarakFont.serif(16)).lineSpacing(6).foregroundStyle(SarakColor.ink)
                }
                .padding(.vertical, 6)
                .swipeActions {
                    Button("삭제", role: .destructive) {
                        store.toggleBookmark(Verse(bookId: b.bookId, chapter: b.chapter, number: b.verse, text: b.text), bookName: b.bookName)
                    }
                    Button("카드") {
                        share = ShareVerses(verses: [Verse(bookId: b.bookId, chapter: b.chapter, number: b.verse, text: b.text)], bookName: b.bookName)
                    }
                    .tint(SarakColor.indigo)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SarakColor.surface)
        .navigationTitle("북마크한 말씀")
        .sheet(item: $share) { s in ShareCardSheet(verses: s.verses, bookName: s.bookName, note: nil, dayNumber: nil) }
    }
}
