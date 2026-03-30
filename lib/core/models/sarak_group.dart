import 'package:cloud_firestore/cloud_firestore.dart';

class SarakGroup {
  final String id;
  final String name;
  final String createdBy;
  final String inviteCode;
  final List<String> memberUids;
  
  // 👉 새로 추가된 부분이에요! (읽기 계획 정보 3가지)
  final String planType;
  final int totalDays;
  final DateTime? startDate;
  
  final DateTime createdAt;

  SarakGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.inviteCode,
    required this.memberUids,
    
    // 👉 새로 추가된 부분의 기본값을 정해줍니다.
    this.planType = '90일 통독',
    this.totalDays = 90,
    this.startDate,
    
    required this.createdAt,
  });

  factory SarakGroup.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SarakGroup(
      id: doc.id,
      name: d['name'] ?? '',
      createdBy: d['createdBy'] ?? '',
      inviteCode: d['inviteCode'] ?? '',
      memberUids: List<String>.from(d['members'] ?? []),
      
      // 👉 파이어베이스에서 데이터를 가져올 때 새로 추가된 부분도 읽어옵니다.
      planType: d['planType'] ?? '90일 통독',
      totalDays: d['totalDays'] ?? 90,
      startDate: (d['startDate'] as Timestamp?)?.toDate(),
      
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'createdBy': createdBy,
    'inviteCode': inviteCode,
    'members': memberUids,
    
    // 👉 파이어베이스에 저장할 때 새로 추가된 부분도 같이 저장합니다.
    'planType': planType,
    'totalDays': totalDays,
    'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
    
    'createdAt': Timestamp.fromDate(createdAt),
  };
}