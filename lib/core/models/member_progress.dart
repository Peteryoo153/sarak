import 'package:cloud_firestore/cloud_firestore.dart';

class MemberProgress {
  final String uid;
  final String name;
  final int currentDay;
  final bool todayCompleted;
  final String? todayComment;
  final double progress;
  final int streak;
  final DateTime? lastReadAt;

  MemberProgress({
    required this.uid,
    required this.name,
    this.currentDay = 1,
    this.todayCompleted = false,
    this.todayComment,
    this.progress = 0.0,
    this.streak = 0,
    this.lastReadAt,
  });

  factory MemberProgress.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MemberProgress(
      uid: doc.id,
      name: d['name'] ?? '',
      currentDay: d['currentDay'] ?? 1,
      todayCompleted: d['todayCompleted'] ?? false,
      todayComment: d['todayComment'],
      progress: (d['progress'] ?? 0.0).toDouble(),
      streak: d['streak'] ?? 0,
      lastReadAt: (d['lastReadAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'currentDay': currentDay,
    'todayCompleted': todayCompleted,
    'todayComment': todayComment,
    'progress': progress,
    'streak': streak,
    'lastReadAt': lastReadAt != null ? Timestamp.fromDate(lastReadAt!) : null,
  };
}