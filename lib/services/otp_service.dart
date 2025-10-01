import 'package:cloud_functions/cloud_functions.dart';

class OtpService {
  OtpService._();
  static final instance = OtpService._();
  final _f = FirebaseFunctions.instanceFor(region: 'us-central1');


  Future<void> sendOtp(String email) async {
    await _f.httpsCallable('sendOtp').call({'email': email});
  }

  Future<String> verifyOtp(String email, String otp) async {
    final res =
        await _f.httpsCallable('verifyOtp').call({'email': email, 'otp': otp});
    return (res.data as Map)['token'] as String;
  }

  Future<void> resetPassword(
      String email, String token, String newPassword) async {
    await _f.httpsCallable('resetPassword').call({
      'email': email,
      'token': token,
      'newPassword': newPassword,
    });
  }
}
