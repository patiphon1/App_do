import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;

  /// chatId จาก uid สองฝั่ง (เรียงเพื่อให้ unique)
  String chatIdOf(String a, String b) => (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';

  /// สร้างห้อง (ครั้งแรก) ให้มีฟิลด์ตาม Rules
  Future<void> ensureChat({
    required String peerId,
    required String kind,       // 'donate' | 'request' | 'swap'
    String? peerName,
  }) async {
    final uid = myUid;
    final cid = chatIdOf(uid, peerId);
    final chatRef = _fire.collection('chats').doc(cid);

    await chatRef.set({
      'users': [uid, peerId],
      'peerMap': { uid: peerId, peerId: uid },
      'kind': kind,
      'lastText': null,
      'lastAt': FieldValue.serverTimestamp(), // หรือจะตั้งเป็น null ก็ได้ตาม Rules
      'unread': { uid: 0, peerId: 0 },
      if (peerName != null) 'peerName': peerName,
    }, SetOptions(merge: true));
  }

  /// ส่งข้อความ + อัปเดตสรุปแชท (lastText/lastAt/unread)
  Future<void> sendMessage({
    required String peerId,
    required String text,
    required String kind, // 'donate' | 'request' | 'swap'
  }) async {
    final uid = myUid;
    final cid = chatIdOf(uid, peerId);
    final now = FieldValue.serverTimestamp();

    final chatRef = _fire.collection('chats').doc(cid);
    final msgRef = chatRef.collection('messages').doc();

    await _fire.runTransaction((trx) async {
      // ✅ อัปเดตเฉพาะฟิลด์ที่ Rules อนุญาตในขั้น update
      // (ไม่แตะ users)
      trx.set(chatRef, {
        // ถ้าห้องยังไม่เคยมี kind (สร้างครั้งแรกด้วย ensureChat) ก็ไม่จำเป็นต้องส่งซ้ำ
        'lastText': text,
        'lastAt': now,
        'unread': { peerId: FieldValue.increment(1), uid: 0 },
      }, SetOptions(merge: true));

      // ✅ เขียนข้อความ ใช้ createdAt ตาม Rules
      trx.set(msgRef, {
        'from': uid,
        'to': peerId,            // ไม่ได้ถูกบังคับโดย Rules แต่ใส่ไว้ก็ดี
        'text': text,
        'createdAt': now,
      });
    });
  }

  /// อ่านข้อความในห้อง (ใหม่อยู่ล่าง)
  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String peerId) {
    final cid = chatIdOf(myUid, peerId);
    return _fire
        .collection('chats')
        .doc(cid)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// อ่านรายชื่อห้องของฉัน ตาม kind
  Stream<QuerySnapshot<Map<String, dynamic>>> myThreads({required String kind}) {
    return _fire
        .collection('chats')
        .where('users', arrayContains: myUid)
        .where('kind', isEqualTo: kind)
        .orderBy('lastAt', descending: true)
        .snapshots();
  }

  /// เคลียร์ unread ของตัวเองในห้องนั้น
  Future<void> clearUnread(String peerId) async {
    final cid = chatIdOf(myUid, peerId);
    await _fire.collection('chats').doc(cid).set({
      'unread': { myUid: 0 } // merge:true จะอัปเดตเฉพาะ key ของเรา
    }, SetOptions(merge: true));
  }
}
