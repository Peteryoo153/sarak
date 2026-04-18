import 'package:cloud_firestore/cloud_firestore.dart';

class SarakGroup {
  final String id;
  final String name;
  final String createdBy;
  final String inviteCode;
  final List<String> memberUids;

  // 플랜 메타
  final String planType; // 하위 호환용 라벨 (= rangeName과 보통 동일)
  final int totalDays;
  final DateTime? startDate;

  // 실제 플랜 구성
  final String rangeName; // 예: "신구약 전체"
  final int startBookId;
  final int endBookId;
  final int minutesPerDay;
  final List<Map<String, dynamic>> schedule; // DayPlan 직렬화 리스트

  final DateTime createdAt;

  SarakGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.inviteCode,
    required this.memberUids,
    this.planType = '90일 통독',
    this.totalDays = 90,
    this.startDate,
    this.rangeName = '',
    this.startBookId = 1,
    this.endBookId = 66,
    this.minutesPerDay = 15,
    this.schedule = const [],
    required this.createdAt,
  });

  bool get hasSchedule => schedule.isNotEmpty;

  factory SarakGroup.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawSchedule = d['schedule'] as List<dynamic>?;
    return SarakGroup(
      id: doc.id,
      name: d['name'] ?? '',
      createdBy: d['createdBy'] ?? '',
      inviteCode: d['inviteCode'] ?? '',
      memberUids: List<String>.from(d['members'] ?? []),
      planType: d['planType'] ?? '90일 통독',
      totalDays: d['totalDays'] ?? 90,
      startDate: (d['startDate'] as Timestamp?)?.toDate(),
      rangeName: d['rangeName'] ?? d['planType'] ?? '',
      startBookId: d['startBookId'] ?? 1,
      endBookId: d['endBookId'] ?? 66,
      minutesPerDay: d['minutesPerDay'] ?? 15,
      schedule: rawSchedule == null
          ? const []
          : rawSchedule
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'createdBy': createdBy,
        'inviteCode': inviteCode,
        'members': memberUids,
        'planType': planType,
        'totalDays': totalDays,
        'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
        'rangeName': rangeName,
        'startBookId': startBookId,
        'endBookId': endBookId,
        'minutesPerDay': minutesPerDay,
        'schedule': schedule,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
