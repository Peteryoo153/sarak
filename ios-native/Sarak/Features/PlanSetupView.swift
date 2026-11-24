import SwiftUI

/// 범위 + 기간 선택 (개인 플랜, 그룹 만들기/수정에서 함께 사용)
struct PlanPicker: View {
    @Binding var preset: RangePreset
    @Binding var days: Int
    static let dayOptions = [30, 60, 90, 180, 365]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "읽을 범위")
                ForEach(RangePreset.all) { p in
                    Button { preset = p } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.label).font(.subheadline.weight(.medium)).foregroundStyle(SarakColor.ink)
                                Text("\(p.chapters)장").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                            }
                            Spacer()
                            Image(systemName: preset == p ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18)).foregroundStyle(preset == p ? SarakColor.primaryFill : SarakColor.inkFaint)
                        }
                        .padding(.vertical, 12).contentShape(Rectangle())
                        .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(preset == p ? .isSelected : [])
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "기간")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.dayOptions, id: \.self) { d in
                            Button(d == 365 ? "1년" : "\(d)일") { days = d }
                                .buttonStyle(PillButtonStyle(selected: days == d))
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                Image(systemName: "clock").font(.system(size: 18)).foregroundStyle(SarakColor.mintInk)
                    .frame(width: 40, height: 40).background(SarakColor.mintSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("하루 약 \(ScheduleEngine.estimatedMinutes(preset: preset, days: days))분").font(.subheadline.weight(.medium)).foregroundStyle(SarakColor.ink)
                    Text("\(preset.label)을 \(days == 365 ? "1년" : "\(days)일") 동안 나눠 읽어요").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct PlanSetupView: View {
    @Environment(PlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var preset = RangePreset.all[0]
    @State private var days = 365
    @State private var confirmReplace = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PlanPicker(preset: $preset, days: $days)
                    if store.activeGroupId != nil {
                        Text("지금은 그룹 플랜으로 읽고 있어요. 개인 플랜을 시작하면 홈에는 개인 플랜이 보이고, 그룹 기록은 그대로 남아요.")
                            .font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                    }
                }
                .padding(32)
            }
            .background(SarakColor.surface)
            .safeAreaInset(edge: .bottom) {
                Button("오늘부터 시작하기") {
                    if store.plan != nil && store.activeGroupId == nil { confirmReplace = true } else { start() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(SarakColor.surface)
            }
            .navigationTitle("통독 플랜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .confirmationDialog("새 플랜으로 바꿀까요?", isPresented: $confirmReplace, titleVisibility: .visible) {
                Button("새 플랜 시작 (기존 진도 초기화)", role: .destructive) { start() }
            } message: {
                Text("오늘이 Day 1이 되고, 지금 개인 플랜의 진도 기록은 지워집니다.")
            }
            .onAppear {
                if let p = store.plan, store.activeGroupId == nil {
                    preset = RangePreset.matching(start: p.startBookId, end: p.endBookId)
                    days = PlanPicker.dayOptions.min { abs($0 - p.totalDays) < abs($1 - p.totalDays) } ?? 365
                }
            }
        }
    }

    private func start() {
        let schedule = ScheduleEngine.generate(startBookId: preset.startBookId, endBookId: preset.endBookId, totalDays: days)
        let plan = ReadingPlan(rangeName: preset.label, startBookId: preset.startBookId, endBookId: preset.endBookId,
                               totalDays: schedule.count, minutesPerDay: schedule.map(\.estimatedMinutes).max() ?? 15,
                               startDate: PlanDates.string(Date()), schedule: schedule, source: PlanStore.personal)
        store.startPersonalPlan(plan)
        dismiss()
    }
}
