import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;

  List<String> _pair(String a, String b) => (a.compareTo(b) < 0) ? [a, b] : [b, a];

  String chatIdOf(String a, String b, {String? postId}) {
    final p = _pair(a, b);
    return (postId == null || postId.isEmpty)
        ? '${p[0]}_${p[1]}'
        : 'p:$postId:${p[0]}_${p[1]}';
  }

  /// สร้าง/อัปเดตห้องให้พร้อมใช้งานกับ Rules/Query
  Future<void> ensureChat({
    required String peerId,
    required String kind,          // 'donate' | 'request' | 'swap'
    String? postId,
    String? postTitle,
  }) async {
    final uid = myUid;
    final cid = chatIdOf(uid, peerId, postId: postId);
    final pair = _pair(uid, peerId);
    final chatRef = _fire.collection('chats').doc(cid);

    await chatRef.set({
      'id': cid,
      'users': pair,
      'peerMap': { uid: peerId, peerId: uid },
      'kind': kind,
      'postId': postId ?? '',
      'postTitle': postTitle ?? '',
      'lastText': FieldValue.delete(),          // ให้เป็น null/ไม่มีได้
      'lastAt': FieldValue.serverTimestamp(),   // ใช้กับ orderBy
      'unread': { pair[0]: 0, pair[1]: 0 },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendSystemMessage({
    required String peerId,
    required String text,
    required String kind,
    String? postId,
    String? postTitle,
  }) async {
    final uid = myUid;
    final cid = chatIdOf(uid, peerId, postId: postId);
    final chatRef = _fire.collection('chats').doc(cid);

    await ensureChat(peerId: peerId, kind: kind, postTitle: postTitle, postId: postId);

    final batch = _fire.batch();
    final msgRef = chatRef.collection('messages').doc();

    batch.set(msgRef, {
      'from': uid,
      'text': text,
      'type': 'system',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(chatRef, {
      'lastText': text,
      'lastAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> sendMessage({
    required String peerId,
    required String text,
    required String kind,
    String? postId,
    String? postTitle,
  }) async {
    final uid = myUid;
    final cid = chatIdOf(uid, peerId, postId: postId);
    final chatRef = _fire.collection('chats').doc(cid);
    final msgRef  = chatRef.collection('messages').doc();

    await ensureChat(peerId: peerId, kind: kind, postTitle: postTitle, postId: postId);

    final batch = _fire.batch();

    batch.set(msgRef, {
      'from': uid,
      'to': peerId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(chatRef, {
      'kind': kind,
      'lastText': text,
      'lastAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unread.$peerId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> clearUnread(String peerId, {String? postId}) async {
    final cid = chatIdOf(myUid, peerId, postId: postId);
    final ref = _fire.collection('chats').doc(cid);
    final snap = await ref.get();
    if (!snap.exists) return;
    await ref.update({
      'unread.$myUid': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String peerId, {String? postId}) {
    final cid = chatIdOf(myUid, peerId, postId: postId);
    return _fire
        .collection('chats')
        .doc(cid)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// รายการห้องของฉันตาม kind (ให้ตรงกับ Rules/Index)
  Stream<QuerySnapshot<Map<String, dynamic>>> myThreads({required String kind}) {
    return _fire
        .collection('chats')
        .where('users', arrayContains: myUid)   // ← ตรงกับ Rules
        .where('kind', isEqualTo: kind)
        .orderBy('lastAt', descending: true)
        .limit(50)                              // ← กัน query กว้างเกิน
        .snapshots();
  }

  /// one-time rating (คงเดิม)
  Future<void> ratePostOnce({
    required String postId,
    required num value, // 0..5
  }) async {
    final uid = myUid;
    final rRef = _fire.collection('posts').doc(postId).collection('ratings').doc(uid);

    await _fire.runTransaction((tx) async {
      final snap = await tx.get(rRef);
      if (snap.exists) {
        throw StateError('คุณให้คะแนนโพสต์นี้ไปแล้ว');
      }
      tx.set(rRef, {
        'value': value,
        'by': uid,
        'at': FieldValue.serverTimestamp(),
      });
    });
  }
}
