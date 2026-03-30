import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final int currentDay;
  final double progress;
  final int streak;
  final bool todayCompleted;
  final String? todayComment;
  final DateTime? lastReadAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.currentDay = 1,
    this.progress = 0.0,
    this.streak = 0,
    this.todayCompleted = false,
    this.todayComment,
    this.lastReadAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      photoUrl: d['photoUrl'],
      currentDay: d['currentDay'] ?? 1,
      progress: (d['progress'] ?? 0.0).toDouble(),
      streak: d['streak'] ?? 0,
      todayCompleted: d['todayCompleted'] ?? false,
      todayComment: d['todayComment'],
      lastReadAt: (d['lastReadAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'email': email,
    'photoUrl': photoUrl,
    'currentDay': currentDay,
    'progress': progress,
    'streak': streak,
    'todayCompleted': todayCompleted,
    'todayComment': todayComment,
    'lastReadAt': lastReadAt != null ? Timestamp.fromDate(lastReadAt!) : null,
  };
}