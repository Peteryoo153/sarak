import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../database/firestore_service.dart';
import '../models/app_user.dart';
import '../models/sarak_group.dart';

// ─── Firebase Auth 상태 ───
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ─── 서비스 ───
final authServiceProvider = Provider((ref) => AuthService());
final firestoreServiceProvider = Provider((ref) => FirestoreService());

// ─── 내 유저 정보 (Firestore) ───
final myProfileProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchUser(uid);
});

// ─── 내가 속한 그룹 목록 ───
final myGroupsProvider = StreamProvider<List<SarakGroup>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.valueOrNull == null) return Stream.value([]);
  return ref.read(firestoreServiceProvider).watchMyGroups();
});

// ─── 특정 그룹의 멤버 목록 ───
final groupMembersProvider =
    StreamProvider.family<List<AppUser>, List<String>>((ref, memberUids) {
  return ref.read(firestoreServiceProvider).watchGroupMembers(memberUids);
});

// ─── Auth 서비스 ───
class AuthService {
  final _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final _firestore = FirestoreService();

  Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    if (result.user != null) {
      await _firestore.createUserIfNeeded(result.user!);
    }
    return result.user;
  }

  Future<User?> signInWithApple() async {
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
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}