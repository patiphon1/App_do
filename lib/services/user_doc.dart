// lib/services/user_doc.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

class UserDoc {
  /// สตรีมเอกสารสำหรับการ "ดูโปรไฟล์"
  /// - เจ้าของเอง => users/{uid}
  /// - แอดมิน => users/{uid}
  /// - ผู้ใช้ทั่วไปดูคนอื่น => publicUsers/{uid}
  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamForView(String targetUid) {
    final auth = FirebaseAuth.instance;
    final me = auth.currentUser?.uid;

    if (me != null && me == targetUid) {
      // ดูของตัวเอง
      return FirebaseFirestore.instance.doc('users/$targetUid').snapshots();
    }

    // เช็กบทบาทของเรา
    final myDocStream =
        FirebaseFirestore.instance.doc('users/$me').snapshots();

    return myDocStream.switchMap((mine) {
      final role = mine.data()?['role'];
      if (role == 'admin') {
        return FirebaseFirestore.instance.doc('users/$targetUid').snapshots();
      }
      // ผู้ใช้ทั่วไป → publicUsers
      return FirebaseFirestore.instance.doc('publicUsers/$targetUid').snapshots();
    });
  }
}
