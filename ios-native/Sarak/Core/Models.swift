import Foundation
import FirebaseFirestore

struct SarakGroup: Identifiable, Hashable {
    var id: String
    var name: String
    var createdBy: String
    var inviteCode: String
    var memberUids: [String]
    var totalDays: Int
    var startDate: Date?
    var rangeName: String
    var startBookId: Int
    var endBookId: Int
    var minutesPerDay: Int
    var schedule: [DayPlan]
    var createdAt: Date

    var hasSchedule: Bool { !schedule.isEmpty }

    init(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]
        id = doc.documentID
        name = d["name"] as? String ?? ""
        createdBy = d["createdBy"] as? String ?? ""
        inviteCode = d["inviteCode"] as? String ?? ""
        memberUids = d["members"] as? [String] ?? []
        totalDays = (d["totalDays"] as? NSNumber)?.intValue ?? 90
        startDate = (d["startDate"] as? Timestamp)?.dateValue()
        rangeName = (d["rangeName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? d["planType"] as? String ?? ""
        startBookId = (d["startBookId"] as? NSNumber)?.intValue ?? 1
        endBookId = (d["endBookId"] as? NSNumber)?.intValue ?? 66
        minutesPerDay = (d["minutesPerDay"] as? NSNumber)?.intValue ?? 15
        createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let raw = d["schedule"] as? [[String: Any]] ?? []
        schedule = raw.compactMap { m in
            guard let json = try? JSONSerialization.data(withJSONObject: m) else { return nil }
            return try? JSONDecoder().decode(DayPlan.self, from: json)
        }
    }

    var asLocalPlan: ReadingPlan {
        ReadingPlan(rangeName: rangeName, startBookId: startBookId, endBookId: endBookId, totalDays: totalDays,
                    minutesPerDay: minutesPerDay, startDate: PlanDates.string(startDate ?? createdAt),
                    schedule: schedule, source: PlanStore.groupSource(id), groupId: id, groupName: name)
    }

    /// 그룹 시작일 기준 오늘이 몇 Day인지
    var todayDay: Int {
        let cal = Calendar.current
        let d = cal.dateComponents([.day], from: cal.startOfDay(for: startDate ?? createdAt), to: cal.startOfDay(for: Date())).day ?? 0
        return min(max(d + 1, 1), max(totalDays, 1))
    }
}

struct MemberProgress: Identifiable, Hashable {
    var uid: String
    var name: String
    var currentDay: Int
    var todayCompleted: Bool
    var todayComment: String?
    var progress: Double
    var streak: Int
    var lastReadAt: Date?
    var id: String { uid }

    /// 오늘 날짜에 실제로 읽었는지 (자정이 지나면 자동으로 false — 기존 앱의 '오늘 완료' 고정 버그 수정)
    var completedToday: Bool {
        guard todayCompleted, let lastReadAt else { return false }
        return Calendar.current.isDateInToday(lastReadAt)
    }

    init(uid: String, name: String, currentDay: Int, todayCompleted: Bool, todayComment: String?,
         progress: Double, streak: Int, lastReadAt: Date?) {
        self.uid = uid; self.name = name; self.currentDay = currentDay; self.todayCompleted = todayCompleted
        self.todayComment = todayComment; self.progress = progress; self.streak = streak; self.lastReadAt = lastReadAt
    }

    init(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]
        uid = doc.documentID
        name = d["name"] as? String ?? ""
        currentDay = (d["currentDay"] as? NSNumber)?.intValue ?? 1
        todayCompleted = d["todayCompleted"] as? Bool ?? false
        todayComment = d["todayComment"] as? String
        progress = (d["progress"] as? NSNumber)?.doubleValue ?? 0
        streak = (d["streak"] as? NSNumber)?.intValue ?? 0
        lastReadAt = (d["lastReadAt"] as? Timestamp)?.dateValue()
    }

    var firestore: [String: Any] {
        [
            "name": name, "currentDay": currentDay, "todayCompleted": todayCompleted,
            "todayComment": todayComment as Any, "progress": progress, "streak": streak,
            "lastReadAt": lastReadAt.map { Timestamp(date: $0) } as Any,
        ]
    }
}

struct Cheer: Identifiable, Hashable {
    var id: String
    var groupId: String
    var groupName: String
    var fromUid: String
    var fromName: String
    var toUid: String
    var createdAt: Date

    init(doc: DocumentSnapshot, groupId: String, groupName: String) {
        let d = doc.data() ?? [:]
        id = doc.documentID
        self.groupId = groupId
        self.groupName = groupName
        fromUid = d["from"] as? String ?? ""
        fromName = d["fromName"] as? String ?? ""
        toUid = d["to"] as? String ?? ""
        createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
}

struct CompletionRecord: Identifiable, Hashable {
    var id: String
    var planName: String
    var range: String
    var startDate: Date
    var completedAt: Date
}
