import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_gate.dart';
import 'features/auth/pages/register_page.dart';
import 'features/auth/pages/forgot_password_page.dart';
import 'features/auth/pages/verify_code_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
