import SwiftUI

enum AppTab: Hashable { case today, calendar, together, more }

struct MainTabView: View {
    @Environment(Session.self) private var session
    @State private var tab: AppTab = .today

    var body: some View {
        TabView(selection: $tab) {
            HomeView(tab: $tab)
                .tabItem { Label("오늘", systemImage: "book.pages") }
                .tag(AppTab.today)
            CalendarView()
                .tabItem { Label("달력", systemImage: "calendar") }
                .tag(AppTab.calendar)
            GroupView()
                .tabItem { Label("함께", systemImage: "person.2") }
                .tag(AppTab.together)
            SettingsView()
                .tabItem { Label("더보기", systemImage: "ellipsis") }
                .tag(AppTab.more)
        }
        .tint(SarakColor.primaryFill)
        .onChange(of: session.pendingInviteCode) { _, code in
            if code != nil { tab = .together }
        }
    }
}
