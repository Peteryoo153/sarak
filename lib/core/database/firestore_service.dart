import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/sarak_group.dart';
import '../models/member_progress.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // ─── 유저 ───

  /// 로그인 시 유저 문서 생성 (이미 있으면 건너뜀)
  Future<void> createUserIfNeeded(User user) async {
    final doc = _db.collection('users').doc(user.uid);
    final snapshot = await doc.get();
    if (!snapshot.exists) {
      await doc.set({
        'name': user.displayName ?? '이름없음',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'currentDay': 1,
        'progress': 0.0,
        'streak': 0,
        'todayCompleted': false,
        'todayComment': null,
        'lastReadAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// 유저 정보 스트림
  Stream<AppUser?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
      (doc) => doc.exists ? AppUser.fromFirestore(doc) : null,
    );
  }

  /// 읽기 완료 시 업데이트
  Future<void> markTodayComplete({String? comment}) async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid).update({
      'todayCompleted': true,
      'todayComment': comment,
      'lastReadAt': FieldValue.serverTimestamp(),
    });
  }

  /// 매일 자정 리셋용 (나중에 Cloud Function으로 대체 가능)
  Future<void> resetTodayStatus() async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid).update({
      'todayCompleted': false,
      'todayComment': null,
    });
  }

  // ─── 그룹 ───

  /// 그룹 생성 (새로운 출석부에 내 이름도 같이 등록합니다!)
  Future<SarakGroup> createGroup(
    String name, {
    String planType = '90일 통독',
    int totalDays = 90,
    DateTime? startDate,
  }) async {
    if (currentUid == null) throw Exception('로그인 필요');
    
    // 1. 그룹 먼저 만들기
    final inviteCode = _generateInviteCode();
    final docRef = await _db.collection('groups').add({
      'name': name,
      'createdBy': currentUid,
      'inviteCode': inviteCode,
      'members': [currentUid],
      'planType': planType, 
      'totalDays': totalDays, 
      'startDate': startDate != null ? Timestamp.fromDate(startDate) : null, 
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. 내 정보 가져오기 (이름을 알아야 하니까요!)
    final userDoc = await _db.collection('users').doc(currentUid).get();
    final userName = userDoc.data()?['name'] ?? '이름없음';

    // 3. 새로운 progress 출석부에 내 시작 정보 저장하기
    final initialProgress = MemberProgress(
      uid: currentUid!,
      name: userName,
      currentDay: 1,
      todayCompleted: false,
      progress: 0.0,
      streak: 0,
    );
    await updateMemberProgress(groupId: docRef.id, progress: initialProgress);

    final doc = await docRef.get();
    return SarakGroup.fromFirestore(doc);
  }

  /// 초대코드로 그룹 참가 (참가할 때도 출석부에 이름을 등록합니다!)
  /// 성공 시 참여한 그룹을, 코드가 잘못되었거나 로그인되지 않았으면 null을 반환
  Future<SarakGroup?> joinGroup(String inviteCode) async {
    if (currentUid == null) return null;

    final query = await _db
        .collection('groups')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final groupDoc = query.docs.first;

    // 1. 그룹 멤버 명단에 내 UID 추가
    await groupDoc.reference.update({
      'members': FieldValue.arrayUnion([currentUid]),
    });

    // 2. 내 정보 가져오기
    final userDoc = await _db.collection('users').doc(currentUid).get();
    final userName = userDoc.data()?['name'] ?? '이름없음';

    // 3. 새로운 progress 출석부에 내 시작 정보 저장하기
    final initialProgress = MemberProgress(
      uid: currentUid!,
      name: userName,
      currentDay: 1,
      todayCompleted: false,
      progress: 0.0,
      streak: 0,
    );
    await updateMemberProgress(groupId: groupDoc.id, progress: initialProgress);

    final refreshed = await groupDoc.reference.get();
    return SarakGroup.fromFirestore(refreshed);
  }

  /// 내가 속한 그룹 목록 스트림
  Stream<List<SarakGroup>> watchMyGroups() {
    if (currentUid == null) return Stream.value([]);
    return _db
        .collection('groups')
        .where('members', arrayContains: currentUid)
        .snapshots()
        .map((snap) => snap.docs.map(SarakGroup.fromFirestore).toList());
  }

  /// 특정 그룹의 멤버 정보 스트림
  Stream<List<AppUser>> watchGroupMembers(List<String> memberUids) {
    if (memberUids.isEmpty) return Stream.value([]);
    // Firestore 'in' 쿼리는 최대 30개
    final uids = memberUids.take(30).toList();
    return _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids)
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromFirestore).toList());
  }

  /// 6자리 초대코드 생성
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ─── 그룹 멤버 진행 상황 ───

  /// 1. 멤버의 성경 읽기 진행 상황 저장하기
  Future<void> updateMemberProgress({
    required String groupId,
    required MemberProgress progress,
  }) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('progress') 
        .doc(progress.uid)
        .set(progress.toFirestore(), SetOptions(merge: true));
  }

  /// 2. 그룹 멤버들의 진행 상황 실시간으로 불러오기
  Stream<List<MemberProgress>> streamGroupProgress(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('progress')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MemberProgress.fromFirestore(doc))
            .toList());
  }

  /// 3. 멤버 내보내기 또는 내가 그룹에서 나가기 (기존 함수)
  Future<void> removeMember(String groupId, String memberUid) async {
    // 1. 그룹 멤버 명단에서 이름 지우기
    await _db.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([memberUid]),
    });

    // 2. 진행 상황(출석부) 데이터도 깔끔하게 지우기
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('progress')
        .doc(memberUid)
        .delete();
  }

  /// 🌟 3-1. 내가 스스로 그룹에서 나가기 (UI에서 호출하는 함수)
  Future<void> leaveGroup(String groupId) async {
    if (currentUid == null) return; // 로그인 안 되어 있으면 무시
    await removeMember(groupId, currentUid!); // 내 아이디를 넣어서 삭제 실행
  }

  // ─── 통독 완주 기록 (🏆 칭호 및 훈장용) ───

  /// 4. 통독 완주 기록 저장하기
  Future<void> saveCompletionRecord({
    required String planName,
    required DateTime startDate,
    required String range,
  }) async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid).collection('completed_plans').add({
      'planName': planName,
      'startDate': Timestamp.fromDate(startDate),
      'completedAt': FieldValue.serverTimestamp(),
      'range': range,
    });
  }

  /// 5. 통독 완주 기록 불러오기 (스트림)
  Stream<List<Map<String, dynamic>>> watchCompletionRecords() {
    if (currentUid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(currentUid)
        .collection('completed_plans')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }
}