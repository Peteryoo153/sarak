import SwiftUI
import UserNotifications

struct WordAlertsView: View {
    @Environment(PathStore.self) private var path
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @State private var s = WordAlerts.load()
    @State private var denied = false
    private var skipToday: Binding<Bool> {
        Binding { s.skipDate == WordAlerts.dayKey(Date()) } set: { s.skipDate = $0 ? WordAlerts.dayKey(Date()) : nil }
    }
    var body: some View {
        Form {
            if denied {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("아이폰 설정에서 알림이 꺼져 있어요").font(.headline)
                        Text("켜 두면 정한 시간에 말씀이 찾아가요.").font(.footnote).foregroundStyle(Ink.sub)
                        Button("아이폰 설정 열기") { openURL(URL(string: UIApplication.openSettingsURLString)!) }.buttonStyle(SarakButtonStyle()).padding(.top, 8)
                    }.padding(.vertical, 8)
                }
                .listRowBackground(SarakHour.morning.page)
            }
            Section {
                Toggle("말씀 알림", isOn: Binding(get: { s.enabled && !denied }, set: { on in
                    if on { Task { let ok = await WordAlerts.request(); denied = !ok; s.enabled = ok } } else { s.enabled = false }
                }))
                Toggle("오늘 하루 쉬기", isOn: skipToday).disabled(!s.enabled)
            }
            Section {
                ForEach($s.slots) { $slot in
                    HStack(spacing: 14) {
                        HourChip(hour: slot.hour)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(slot.hour.alertTitle)
                            DatePicker(slot.hour.alertTitle, selection: Binding {
                                Calendar.current.date(bySettingHour: slot.h, minute: slot.m, second: 0, of: Date()) ?? Date()
                            } set: { d in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: d); slot.h = c.hour ?? 0; slot.m = c.minute ?? 0
                            }, displayedComponents: .hourAndMinute).labelsHidden().scaleEffect(0.86, anchor: .leading)
                        }
                        Spacer()
                        Toggle(slot.hour.alertTitle, isOn: $slot.on).labelsHidden()
                    }
                }
            } footer: { Text("아침만 소리가 나고, 나머지는 조용히 찾아가요.") }
            .disabled(!s.enabled)
            Section {
                Toggle("잠금화면에 말씀 보이기", isOn: $s.showVerse)
                Button("기본값으로 되돌리기") { s.slots = WordAlerts.Slot.defaults; s.showVerse = true }.foregroundStyle(Ink.ink)
            }
        }
        .tint(Ink.primary).scrollContentBackground(.hidden).background(Ink.canvas)
        .navigationTitle("알림")
        .onChange(of: s) { _, v in
            WordAlerts.save(v)
            Task { await WordAlerts.reschedule(v, from: path.readToday ? max(path.nextDay - 1, 1) : path.nextDay, readToday: path.readToday) }
        }
        .task(id: phase) {
            let st = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            denied = st == .denied
        }
    }
}

/// 첫 실행: 질문 없이, 네 번의 자리를 보여 주고 알림을 묻습니다.
struct WelcomeView: View {
    var done: () -> Void
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading) {
                        Spacer(minLength: 80)
                        Text("하루 네 번,\n말씀이 사락\n찾아갑니다.").font(SarakFont.serif(36)).lineSpacing(2).foregroundStyle(Ink.ink).accessibilityAddTraits(.isHeader)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height * 0.46, alignment: .leading)
                    .padding(.horizontal, 28).padding(.bottom, 110)
                    .background { SarakPage(hour: .morning, lift: 110).padding(EdgeInsets(top: -geo.safeAreaInsets.top, leading: -geo.safeAreaInsets.leading, bottom: 0, trailing: -geo.safeAreaInsets.trailing)) }
                    VStack(spacing: 28) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 18) {
                            ForEach(WordAlerts.Slot.defaults) { s in
                                HStack(spacing: 12) {
                                    HourChip(hour: s.hour)
                                    VStack(alignment: .leading) {
                                        Text(s.hour.name)
                                        Text(Calendar.current.date(bySettingHour: s.h, minute: s.m, second: 0, of: Date())!, format: .dateTime.hour().minute())
                                            .font(.footnote).foregroundStyle(Ink.sub)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        VStack(spacing: 12) {
                            Button("말씀 받기") {
                                Task {
                                    var s = WordAlerts.load(); s.enabled = await WordAlerts.request(); WordAlerts.save(s); done()
                                }
                            }.buttonStyle(SarakButtonStyle())
                            Text("시간은 언제든 바꿀 수 있어요").font(.footnote).foregroundStyle(Ink.sub)
                        }
                    }
                    .frame(maxWidth: 460).padding(24)
                }
            }
            .scrollClipDisabled()
        }
        .foregroundStyle(Ink.ink).background(Ink.canvas)
    }
}
