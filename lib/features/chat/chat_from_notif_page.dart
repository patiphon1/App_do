import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_p2p_page.dart';

class ChatFromNotificationPage extends StatelessWidget {
  final String chatId;
  const ChatFromNotificationPage({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final me = FirebaseAuth.instance.currentUser;

    if (me == null) {
      // กันกรณีเปิดจาก noti ตอนยังไม่ล็อกอิน
      return const Scaffold(body: Center(child: Text('กรุณาเข้าสู่ระบบอีกครั้ง')));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: db.collection('chats').doc(chatId).get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(body: Center(child: Text('ไม่พบห้องแชท')));
        }

        final data = snap.data!.data()!;
        final users = (data['users'] as List?) ?? const [];
        final String peerId = users.firstWhere((u) => u != me.uid, orElse: () => '') as String;

        if (peerId.isEmpty) {
          return const Scaffold(body: Center(child: Text('ห้องแชทไม่ถูกต้อง')));
        }

        // fields ที่หน้า ChatP2PPage ต้องการ
        final String kind      = (data['kind'] as String?) ?? 'donate';
        final String postId    = (data['postId'] as String?) ?? '';
        final String postTitle = (data['postTitle'] as String?) ?? '';

        // ไปหน้าแชทจริงในเฟรมถัดไป
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChatP2PPage(
                peerId: peerId,
                kind: kind,
                postId: postId,
                postTitle: postTitle,
                chatId: chatId,
              ),
            ),
          );
        });

        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }
}
