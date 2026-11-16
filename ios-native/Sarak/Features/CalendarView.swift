import SwiftUI

/// 실제로 읽은 '날짜' 기준 달력 (기존 앱의 하루 밀림 버그 없이 completedAt 날짜로 표시)
struct CalendarView: View {
    @Environment(PlanStore.self) private var store
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var selected: Date?

    private let cal = Calendar.current
    private let weekLabels = ["월", "화", "수", "목", "금", "토", "일"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    stats
                    grid
                    detail
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .background(SarakColor.surface)
            .onAppear { store.reload() }
        }
    }

    private var header: some View {
        HStack {
            Text("달력").font(SarakFont.title1).foregroundStyle(SarakColor.ink)
            Spacer()
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("이전 달")
            Text(monthTitle).font(.system(size: 15, weight: .bold)).foregroundStyle(SarakColor.ink).monospacedDigit()
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel("다음 달")
        }
        .foregroundStyle(SarakColor.ink)
        .padding(.top, 12)
    }

    private var monthTitle: String {
        let c = cal.dateComponents([.year, .month], from: month)
        return "\(c.year!)년 \(c.month!)월"
    }

    private func shift(_ n: Int) {
        month = cal.date(byAdding: .month, value: n, to: month)!
        selected = nil
    }

    private var daysInMonth: [Date] {
        let range = cal.range(of: .day, in: .month, for: month)!
        return range.map { cal.date(byAdding: .day, value: $0 - 1, to: month)! }
    }

    private var stats: some View {
        let readThisMonth = daysInMonth.filter { !store.entries(on: $0).isEmpty }.count
        return HStack(spacing: 8) {
            stat("\(store.streak)일", "연속 읽기", SarakColor.streak)
            stat("\(store.bestStreak)일", "최고 연속", SarakColor.ink)
            stat("\(readThisMonth)일", "이번 달", SarakColor.ink)
            stat("\(Int((store.progress * 100).rounded()))%", "전체", SarakColor.mintInk)
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 18, weight: .heavy)).foregroundStyle(color).minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(SarakColor.inkMuted)
        }
        .card(padding: 12)
    }

    private var grid: some View {
        let leading = (cal.component(.weekday, from: month) + 5) % 7
        let today = cal.startOfDay(for: Date())
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(spacing: 8) {
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(weekLabels, id: \.self) { Text($0).font(SarakFont.micro).foregroundStyle(SarakColor.inkMuted) }
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 42) }
                ForEach(daysInMonth, id: \.self) { d in
                    let entries = store.entries(on: d)
                    let done = !entries.isEmpty
                    let hasNote = entries.contains { !($0.entry.comment ?? "").isEmpty }
                    let isToday = d == today
                    let inPlan = store.plan.map { cal.startOfDay(for: $0.start) <= d } ?? false
                    let missed = !done && d < today && inPlan
                    let isSel = selected == d
                    Button { selected = done ? (isSel ? nil : d) : nil } label: {
                        Text("\(cal.component(.day, from: d))")
                            .font(.system(size: 13, weight: done || isToday ? .bold : .medium))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(done ? SarakColor.mintInk : isToday ? SarakColor.primaryFill : missed ? SarakColor.inkMuted : SarakColor.inkFaint)
                            .background(done ? SarakColor.mintSoft : missed ? SarakColor.sunken : .clear,
                                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .stroke(isToday ? SarakColor.primaryFill : isSel ? SarakColor.mintInk : .clear, lineWidth: 2)
                            }
                            .overlay(alignment: .bottom) {
                                if hasNote { Circle().fill(SarakColor.streak).frame(width: 4, height: 4).padding(.bottom, 5) }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(cal.component(.day, from: d))일\(done ? ", 읽음" : missed ? ", 못 읽음" : "")\(hasNote ? ", 묵상 메모 있음" : "")")
                }
            }
            HStack(spacing: 14) {
                legend(SarakColor.mintSoft, "읽음")
                legend(SarakColor.sunken, "못 읽음")
                HStack(spacing: 5) { Circle().fill(SarakColor.streak).frame(width: 5, height: 5); Text("묵상 메모") }
            }
            .font(.system(size: 11)).foregroundStyle(SarakColor.inkMuted)
            .padding(.top, 4)
        }
        .card(padding: 16)
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) { RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 10, height: 10); Text(t) }
    }

    @ViewBuilder private var detail: some View {
        if let d = selected {
            ForEach(store.entries(on: d), id: \.day) { item in
                let range = store.plan?.day(item.day)?.displayRange ?? ""
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(cal.component(.month, from: d))월 \(cal.component(.day, from: d))일 · Day \(item.day) · \(range)")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(SarakColor.mintInk)
                    if let c = item.entry.comment, !c.isEmpty {
                        Text(c).font(SarakFont.serif(16)).lineSpacing(8).foregroundStyle(SarakColor.ink)
                    } else {
                        Text("남긴 한마디가 없어요").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted)
                    }
                }
                .card(padding: 18)
            }
        } else if store.plan == nil {
            Text("플랜을 시작하면 읽은 날이 여기에 쌓여요.").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted).padding(.top, 8)
        } else {
            Text("읽은 날을 누르면 그날 남긴 한마디를 볼 수 있어요.").font(SarakFont.caption).foregroundStyle(SarakColor.inkMuted).padding(.top, 8)
        }
    }
}
