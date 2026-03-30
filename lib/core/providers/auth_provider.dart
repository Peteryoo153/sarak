import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authServiceProvider = Provider((ref) => AuthService());

class AuthService {
  final _auth = FirebaseAuth.instance;

  // 🔴 1. 생성자 대신 instance(싱글톤) 사용
  final _googleSignIn = GoogleSignIn.instance;

  Future<User?> signInWithGoogle() async {
    // 🔴 2. v7부터는 사용 전 초기화(initialize) 필수
    await _googleSignIn.initialize();

    // 🔴 3. signIn() 대신 authenticate() 사용
    final googleUser = await _googleSignIn.authenticate();

    // 🔴 4. authentication에서 await 제거 (동기 방식으로 변경됨)
    final googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
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
    return result.user;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
