import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_gate.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/auth/pages/register_page.dart';
import 'features/auth/pages/forgot_password_page.dart';
import 'features/auth/pages/verify_code_page.dart';
import 'services/server_clock.dart';
import 'features/chat/chat_list_page.dart';
import 'features/auth/pages/profile_view_page.dart';
import 'features/auth/pages/profile_edit_page.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ เริ่มต้น Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ เปิด App Check โหมด Debug (ถ้าคุณเปิด enforce ใน Firestore)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // ✅ ล็อกอินชั่วคราว (สำหรับทดสอบ Firestore)
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
    print('👤 Signed in anonymously as: ${FirebaseAuth.instance.currentUser?.uid}');
  }

  await ServerClock.sync();
  print('UID = ${FirebaseAuth.instance.currentUser?.uid}');
  final o = Firebase.app().options;
  print('🔥 Firebase projectId=${o.projectId}, appId=${o.appId}');
  runApp(const App());
}
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Donation/Swap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6EA8FF))),
      home: const AppGate(), // <- ให้ Gate ตัดสินใจไป Login หรือ Home
      routes: {
        '/register': (_) => const RegisterPage(),
        '/forgot': (_) => const ForgotPasswordPage(),
        '/chat': (_) => const ChatListPage(),
        '/profile': (_) => const ProfileViewPage(),
        '/profile/edit': (_) => const ProfileEditPage(),

      },
      onGenerateRoute: (settings) {
        if (settings.name == '/verify') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          final email = args['email'] as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => VerifyCodePage(email: email), 
          );
        }
        return null;
      }
    );
  }
}
