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
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
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
    } catch (e) {
      print("Google Sign-In 에러: $e");
      return null;
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
        await _firestore.createUserIfNeeded(result.user!);
      }
      return result.user;
    } catch (e) {
      print("Apple Sign-In 에러: $e");
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
