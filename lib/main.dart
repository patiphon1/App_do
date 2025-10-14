import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_gate.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/auth/pages/register_page.dart';
import 'features/auth/pages/forgot_password_page.dart';
import 'features/auth/pages/verify_code_page.dart';
import 'services/server_clock.dart';
import 'features/chat/chat_list_page.dart';
import 'features/auth/pages/profile_view_page.dart';
import 'features/auth/pages/profile_edit_page.dart';
import 'features/chat/chat_p2p_page.dart';
// === เพิ่มเติมสำหรับ FCM & Local Notification ===
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'features/chat/chat_from_notif_page.dart';

import 'features/auth/pages/admin_verifications_page.dart';
import 'features/auth/pages/admin_user_manager_page.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// ใช้ตอน background isolate
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ทำแค่ logic เบาๆ (ห้าม UI)
}

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
  'chat_messages',
  'Chat Messages',
  description: 'Notifications for new chat messages',
  importance: Importance.high,
);

Future<void> _initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await _fln.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) {
      // กดแจ้งเตือนตอน foreground
      final chatId = resp.payload;
      if (chatId != null && chatId.isNotEmpty) {
        // ใช้ navigatorKey ก็ได้ แต่ที่นี่เราใช้ pushNamed ผ่าน context ทีหลัง
        // จะ handle ใน onMessageOpenedApp อยู่แล้ว
      }
    },
  );

  await _fln
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_chatChannel);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug, // emulator/เครื่อง dev
    appleProvider: AppleProvider.debug,
  );

  // ตั้ง background handler ให้ FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Local noti channel
  await _initLocalNotifications();

  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _messaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _bootstrapNotifications();
    _listenForegroundMessages();
    _handleNotificationClicks();
    _bindTokenToUserOnAuthChanges();
  }

  Future<void> _bootstrapNotifications() async {
    // ขอ permission (Android 13+/iOS)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // สร้าง token และผูกกับผู้ใช้ถ้าล็อกอินแล้ว
    await _saveCurrentTokenIfSignedIn();

    // token เปลี่ยน (reinstall/clear data)
    _messaging.onTokenRefresh.listen((newToken) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null && newToken.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
          'fcmTokens': {newToken: true}
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> _saveCurrentTokenIfSignedIn() async {
    final u = FirebaseAuth.instance.currentUser;
    final token = await _messaging.getToken();
    if (u != null && token != null && token.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'fcmTokens': {token: true}
      }, SetOptions(merge: true));
    }
  }

  void _bindTokenToUserOnAuthChanges() {
    // เวลา login/logout ให้พยายามผูก token ให้ผู้ใช้ที่เพิ่งล็อกอิน
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveCurrentTokenIfSignedIn();
      }
    });
  }

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // โชว์ local notification เฉพาะตอน foreground
      final noti = message.notification;
      if (noti != null) {
        const androidDetails = AndroidNotificationDetails(
          'chat_messages',
          'Chat Messages',
          channelDescription: 'Notifications for new chat messages',
          importance: Importance.max,
          priority: Priority.high,
        );
        const details = NotificationDetails(android: androidDetails);

        await _fln.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          noti.title,
          noti.body,
          details,
          payload: message.data['chatId'], // เอาไว้เปิดหน้าแชทถ้าต้องการ
        );
      }
    });
  }

 void _handleNotificationClicks() {
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final chatId = message.data['chatId'];
    if (chatId != null && chatId.isNotEmpty) {
      debugPrint('[FCM] onMessageOpenedApp -> chatId=$chatId');
      navigatorKey.currentState?.pushNamed('/chat', arguments: {'chatId': chatId});
    }
  });

  _messaging.getInitialMessage().then((message) {
    if (message != null) {
      final chatId = message.data['chatId'];
      debugPrint('[FCM] getInitialMessage -> chatId=$chatId');
      if (chatId != null && chatId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushNamed('/chat', arguments: {'chatId': chatId});
        });
      }
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Donation/Swap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6EA8FF))),
      home: const AppGate(), // <- ให้ Gate ตัดสินใจไป Login หรือ Home
      routes: {
        '/register': (_) => const RegisterPage(),
        '/forgot': (_) => const ForgotPasswordPage(),
        '/chat': (_) => const ChatListPage(), // รับ arguments: {'chatId': ...}
        '/profile': (_) => const ProfileViewPage(),
        '/profile/edit': (_) => const ProfileEditPage(),

        '/admin': (_) => const AdminVerificationsPage(),
        '/admin/users': (_) => const AdminUserManagerPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/verify') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          final email = args['email'] as String? ?? '';
          return MaterialPageRoute(builder: (_) => VerifyCodePage(email: email));
        }
        return null;
      },
    );
  }
}
