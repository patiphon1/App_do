import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  String get myUid => _auth.currentUser!.uid;
  List<String> _pair(String a, String b) => (a.compareTo(b) < 0) ? [a, b] : [b, a];

  String chatIdOf(String a, String b, {String? postId}) {
    final p = _pair(a, b);
    return (postId == null || postId.isEmpty)
        ? '${p[0]}_${p[1]}'
        : 'p:$postId:${p[0]}_${p[1]}';
  }

  /// เตรียมห้องให้พร้อมใช้งาน/Query ตาม Rules
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
      'lastText': FieldValue.delete(),
      'lastAt': FieldValue.serverTimestamp(),
      'unread': { pair[0]: 0, pair[1]: 0 },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  Future<void> ratePostOnce({
    required String postId,
    required num value, // 0..5
  }) async {
    final uid = myUid;

    // validate ฝั่งแอป (rules ก็ตรวจซ้ำอยู่แล้ว)
    final v = value.toDouble();
    if (v < 0 || v > 5) {
      throw ArgumentError('rating must be between 0 and 5');
    }

    final postRef = _fire.collection('posts').doc(postId);
    final ratingRef = postRef.collection('ratings').doc(uid); // doc id = raterUid

    // ป้องกันให้คะแนนตัวเอง (เผื่อเรียกเมธอดนี้จากที่อื่น)
    final postSnap = await postRef.get();
    final ownerId = postSnap.data()?['userId'] as String?;
    if (ownerId != null && ownerId == uid) {
      throw StateError('cannot rate your own post');
    }

    // ใช้ transaction เพื่อให้ "create ครั้งเดียว" ตาม rules
    await _fire.runTransaction((tx) async {
      final exist = await tx.get(ratingRef);
      if (exist.exists) {
        throw StateError('already rated');
      }
      tx.set(ratingRef, {
        'value': v,
        'by': uid,
        'at': FieldValue.serverTimestamp(),
      });
    });
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
      // ไม่ส่ง type = 'text' ก็ได้ (Rules อนุมานเป็น text)
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

  Stream<QuerySnapshot<Map<String, dynamic>>> myThreads({required String kind}) {
  return _fire
      .collection('chats')                    
      .where('users', arrayContains: myUid)   
      .where('kind', isEqualTo: kind)         // ✅ กรองตามหมวดหมู่ (บริจาค / ขอรับ / แลกเปลี่ยน)
      .orderBy('lastAt', descending: true)
      .limit(50)
      .snapshots();
}
  
  /// ---------- ส่วน "ส่งรูป" ----------

  /// เปิดแกลเลอรี/กล้อง แล้วคืนไฟล์ (บีบคุณภาพเล็กน้อย)
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: source, imageQuality: 88);
    if (x == null) return null;
    return File(x.path);
  }

  /// อัปโหลดรูปขึ้น Storage แล้วคืน meta ที่ต้องใช้เขียนข้อความภาพ
  Future<({
    String downloadUrl,
    String storagePath,
    int width,
    int height,
    int size
  })> uploadChatImage({
    required String chatId,
    required File file,
  }) async {
    final uid = myUid;
    final ts = DateTime.now().millisecondsSinceEpoch;
    const ext = 'jpg';
    final path = 'posts/$uid/chat/$chatId/$ts.$ext';

    final ref = _storage.ref(path);
    final task = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    await task.whenComplete(() => null);

    final url = await ref.getDownloadURL();
    final meta = await ref.getMetadata();
    final bytes = meta.size ?? 0;

    return (downloadUrl: url, storagePath: path, width: 0, height: 0, size: bytes);
  }

  /// ส่งข้อความประเภท 'image'
  Future<void> sendImageMessage({
    required String peerId,
    required String kind,
    required File imageFile,
    String? postId,
    String? postTitle,
  }) async {
    final uid = myUid;
    final cid = chatIdOf(uid, peerId, postId: postId);
    final chatRef = _fire.collection('chats').doc(cid);

    await ensureChat(peerId: peerId, kind: kind, postId: postId, postTitle: postTitle);

    final m = await uploadChatImage(chatId: cid, file: imageFile);

    final msgRef = chatRef.collection('messages').doc();
    final batch = _fire.batch();

    batch.set(msgRef, {
      'from': uid,
      'to': peerId,
      'type': 'image',
      'imageUrl': m.downloadUrl,
      'storagePath': m.storagePath,
      'width': m.width,
      'height': m.height,
      'size': m.size,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(chatRef, {
      'lastText': '📷 Photo',
      'lastAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unread.$peerId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
