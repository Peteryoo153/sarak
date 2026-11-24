import SwiftUI

enum AppTab: String, Hashable { case room, bible, keep }

struct MainTabView: View {
    @Environment(Session.self) private var session
    @State private var tab: AppTab = .room
    var body: some View {
        TabView(selection: $tab) {
            RoomView().tabItem { Label("골방", systemImage: "door.left.hand.closed") }.tag(AppTab.room)
            BibleView().tabItem { Label("성경", systemImage: "book") }.tag(AppTab.bible)
            KeepView().tabItem { Label("말씀첩", systemImage: "bookmark") }.tag(AppTab.keep)
        }
        .tint(Ink.primary)
        .onChange(of: session.pendingInviteCode) { _, code in if code != nil { tab = .room } }
        #if DEBUG
        .onAppear {
            if Demo.screen == "bible" { tab = .bible }
            if ["keep", "calendar"].contains(Demo.screen) { tab = .keep }
        }
        #endif
    }
}
