import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../database/firestore_service.dart';
import '../models/app_user.dart';
import '../models/sarak_group.dart';

// ─── 서비스 제공자 (Providers) ───
final authServiceProvider = Provider((ref) => AuthService());
final firestoreServiceProvider = Provider((ref) => FirestoreService());

// ─── 1. Firebase Auth 실시간 상태 (앱을 켜자마자 확인) ───
// idTokenChanges()를 사용해야 ID 토큰이 Firestore에 전파된 뒤 스트림이 발화됨
// (authStateChanges는 토큰 전파 전에 발화되어 permission-denied를 유발)
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.idTokenChanges();
});

// ─── 2. 내 상세 프로필 (Firestore 데이터) ───
final myProfileProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return Stream.value(null);

  final firestore = ref.read(firestoreServiceProvider);
  return firestore.watchUser(uid);
});

// ─── 3. 내가 속한 그룹 목록 ───
final myGroupsProvider = StreamProvider<List<SarakGroup>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.valueOrNull == null) return Stream.value([]);

  return ref.read(firestoreServiceProvider).watchMyGroups();
});

// ─── 4. 특정 그룹의 멤버 목록 ───
final groupMembersProvider =
    StreamProvider.family<List<AppUser>, List<String>>((ref, memberUids) {
  return ref.read(firestoreServiceProvider).watchGroupMembers(memberUids);
});

// ─── Auth 서비스 클래스 ───
class AuthService {
  final _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final _firestore = FirestoreService();

  // 구글 로그인
  Future<User?> signInWithGoogle() async {
    try {
      // 🌟 기존 세션이 있는지 먼저 확인 (Silent SignIn)
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      // 없다면 새로 로그인 창 띄우기
      googleUser ??= await _googleSignIn.signIn();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);

      if (result.user != null) {
        // Firestore에 유저 정보 생성/업데이트
        await _firestore.createUserIfNeeded(result.user!);
      }
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? '구글 로그인에 실패했습니다.');
    } catch (_) {
      throw Exception('구글 로그인 중 문제가 발생했습니다.');
    }
  }

  // 애플 로그인
  Future<User?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final result = await _auth.signInWithCredential(oauthCredential);

      if (result.user != null) {
        // Apple은 최초 1회만 이름을 돌려주므로, 이때만 displayName에 채워둔다.
        final fullName = [credential.givenName, credential.familyName]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ');
        if (fullName.isNotEmpty && (result.user!.displayName ?? '').isEmpty) {
          await result.user!.updateDisplayName(fullName);
          await result.user!.reload();
        }
        await _firestore.createUserIfNeeded(_auth.currentUser ?? result.user!);
      }
      return _auth.currentUser ?? result.user;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw Exception(e.message);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? '애플 로그인에 실패했습니다.');
    } catch (_) {
      throw Exception('애플 로그인 중 문제가 발생했습니다.');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // 계정 삭제 (Apple App Store 가이드라인 5.1.1(v) 준수)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인 상태가 아닙니다.');

    try {
      await _deleteUserData(user.uid);
      await user.delete();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // 최근 로그인이 필요하면 재인증 후 재시도
        await _reauthenticate(user);
        await _deleteUserData(user.uid);
        await _auth.currentUser?.delete();
        await _googleSignIn.signOut();
      } else {
        throw Exception(e.message ?? '계정 삭제에 실패했습니다.');
      }
    } catch (_) {
      throw Exception('계정 삭제 중 문제가 발생했습니다.');
    }
  }

  Future<void> _reauthenticate(User user) async {
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : '';

    if (providerId == 'google.com') {
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('재인증이 취소되었습니다.');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } else if (providerId == 'apple.com') {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      await user.reauthenticateWithCredential(oauthCredential);
    } else {
      throw Exception('지원하지 않는 로그인 제공자입니다.');
    }
  }

  Future<void> _deleteUserData(String uid) async {
    final db = FirebaseFirestore.instance;

    // 1. 내가 속한 모든 그룹에서 나가기 (members 배열에서 제거 + progress 문서 삭제)
    final myGroups = await db
        .collection('groups')
        .where('members', arrayContains: uid)
        .get();
    for (final groupDoc in myGroups.docs) {
      await groupDoc.reference.update({
        'members': FieldValue.arrayRemove([uid]),
      });
      await groupDoc.reference.collection('progress').doc(uid).delete();
    }

    // 2. 통독 완주 기록 서브컬렉션 삭제
    final completed = await db
        .collection('users')
        .doc(uid)
        .collection('completed_plans')
        .get();
    for (final doc in completed.docs) {
      await doc.reference.delete();
    }

    // 3. 유저 문서 삭제
    await db.collection('users').doc(uid).delete();
  }
}
