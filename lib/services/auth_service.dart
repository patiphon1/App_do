import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  final _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<UserCredential> signUp(String email, String password, {String? displayName}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
    return cred;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}

String mapAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'อีเมลไม่ถูกต้อง';
    case 'user-disabled':
      return 'บัญชีถูกปิดการใช้งาน';
    case 'user-not-found':
    case 'wrong-password':
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    case 'email-already-in-use':
      return 'อีเมลนี้ถูกใช้แล้ว';
    case 'weak-password':
      return 'รหัสผ่านอ่อนเกินไป';
    default:
      return e.message ?? 'เกิดข้อผิดพลาด';
  }
}
