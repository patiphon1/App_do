// lib/services/chat_service.dart
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

  // ---------- IDs ----------
  String chatIdOf(String a, String b, {String? postId}) {
    final p = _pair(a, b);
    return (postId == null || postId.isEmpty)
        ? '${p[0]}_${p[1]}'
        : 'p:$postId:${p[0]}_${p[1]}';
  }

  // ---------- Chats ----------
  Future<void> ensureChat({
    required String peerId,
    required String kind, // 'announce' | 'donate' | 'swap' | 'request'
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

  Future<void> clearUnreadByChatId(String chatId) async {
    final uid = myUid;
    await _fire.collection('chats').doc(chatId).set({
      'unread.$uid': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // รองรับโค้ดเก่า: svc.clearUnread(peerId, postId: ...)
  Future<void> clearUnread(String peerId, {String? postId}) async {
    final cid = chatIdOf(myUid, peerId, postId: postId);
    await clearUnreadByChatId(cid);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myThreads({required String kind}) {
    return _fire
        .collection('chats')
        .where('users', arrayContains: myUid)
        .where('kind', isEqualTo: kind)
        .orderBy('lastAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // ---------- Messages ----------
  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStreamByChatId(String chatId) {
    return _fire
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // รองรับโค้ดเก่า: svc.messages(peerId, postId: ...)
  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String peerId, {String? postId}) {
    final cid = chatIdOf(myUid, peerId, postId: postId);
    return messagesStreamByChatId(cid);
  }

  // ===== ส่งข้อความ =====
  Future<void> _sendSystem({
    required String chatId,
    required String text,
  }) async {
    final uid = myUid;
    final batch = _fire.batch();
    final chatRef = _fire.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    batch.set(msgRef, {
      'from': uid,
      'type': 'system',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(chatRef, {
      'lastText': text,
      'lastAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> sendText({
    required String chatId,
    required String peerId,
    required String text,
    required String kind,
  }) async {
    final uid = myUid;
    final batch = _fire.batch();
    final chatRef = _fire.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

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

  // wrapper ชื่อเดิม: sendMessage(...)
  Future<void> sendMessage({
    required String peerId,
    required String kind,
    required String text,
    String? postId,
    String? postTitle,
  }) async {
    await ensureChat(peerId: peerId, kind: kind, postId: postId, postTitle: postTitle);
    final cid = chatIdOf(myUid, peerId, postId: postId);
    await sendText(chatId: cid, peerId: peerId, text: text, kind: kind);
  }

  // ===== รูปภาพ =====
  Future<Map<String, String>> uploadChatImage({
    required String chatId,
    required XFile xfile,
  }) async {
    final uid = myUid;
    final ext = xfile.name.split('.').last.toLowerCase();
    final path = 'chat_uploads/$chatId/${DateTime.now().millisecondsSinceEpoch}_$uid.$ext';

    final data = await xfile.readAsBytes();
    final ref = _storage.ref().child(path);
    final meta = SettableMetadata(
      contentType: (ext == 'png')
          ? 'image/png'
          : (ext == 'gif')
              ? 'image/gif'
              : 'image/jpeg',
    );

    await ref.putData(data, meta);
    final url = await ref.getDownloadURL();
    return { 'imageUrl': url, 'storagePath': path };
  }

  Future<void> sendImage({
    required String chatId,
    required String peerId,
    required String imageUrl,
    required String storagePath,
    int? width,
    int? height,
    int? size,
  }) async {
    final uid = myUid;
    final batch = _fire.batch();
    final chatRef = _fire.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    batch.set(msgRef, {
      'from': uid,
      'to': peerId,
      'type': 'image',
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (size != null) 'size': size,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(chatRef, {
      'lastText': '[ส่งรูปภาพ]',
      'lastAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unread.$peerId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // เลือกรูปจากเครื่อง
  Future<XFile?> pickImage({required ImageSource source}) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: source, imageQuality: 85);
    return x;
  }

  // ===== ซิกเนเจอร์ “ตรงตามที่หน้า UI เรียก” =====
  // sendImageMessage(peerId:, kind:, imageFile:, postId:, postTitle:)
  Future<void> sendImageMessage({
    String? chatId,
    required String peerId,
    required XFile imageFile,
    required String kind,
    String? postId,
    String? postTitle,
  }) async {
    final cid = chatId ?? chatIdOf(myUid, peerId, postId: postId);
    // เผื่อห้องยังไม่ถูก set
    await ensureChat(peerId: peerId, kind: kind, postId: postId, postTitle: postTitle);
    final meta = await uploadChatImage(chatId: cid, xfile: imageFile);
    await sendImage(
      chatId: cid,
      peerId: peerId,
      imageUrl: meta['imageUrl']!,
      storagePath: meta['storagePath']!,
    );
  }

  // sendSystemMessage(peerId:, kind:, text:, postId:, postTitle:)
  Future<void> sendSystemMessage({
    required String peerId,
    required String kind,
    required String text,
    String? postId,
    String? postTitle,
  }) async {
    final cid = chatIdOf(myUid, peerId, postId: postId);
    // ให้แน่ใจว่าห้องพร้อมและอัปเดต kind/postTitle ด้วย
    await ensureChat(peerId: peerId, kind: kind, postId: postId, postTitle: postTitle);
    await _sendSystem(chatId: cid, text: text);
  }

  // ===== Rating (1 รอบ/คน/โพสต์) =====
  Future<void> ratePostOnce({
    required String postId,
    required double value, // 1..5
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final intVal = value.round().clamp(1, 5);
    final _fire = FirebaseFirestore.instance;

    final postRef   = _fire.collection('posts').doc(postId);
    final ratingRef = postRef.collection('ratings').doc(uid);

    try {
      await _fire.runTransaction((tx) async {
        // === READS ก่อนทั้งหมด ===
        final postSnap = await tx.get(postRef);
        if (!postSnap.exists) throw Exception('โพสต์ถูกลบหรือไม่พบ');

        final post = postSnap.data() as Map<String, dynamic>;
        final ownerId = post['userId'] as String?;
        if (ownerId == null) throw Exception('โพสต์นี้ไม่มีเจ้าของ');
        if (ownerId == uid) throw Exception('ห้ามให้คะแนนตัวเอง');

        final ratedSnap = await tx.get(ratingRef);
        if (ratedSnap.exists) throw Exception('คุณให้คะแนนโพสต์นี้ไปแล้ว');

        final ownerRef = _fire.collection('users').doc(ownerId);
        final ownerSnap = await tx.get(ownerRef);
        final owner = ownerSnap.data() ?? <String, dynamic>{};

        final prevTotal     = (owner['starsTotal']  ?? 0) as int;
        final prevCount     = (owner['starsRaters'] ?? 0) as int;
        final prevPostTotal = (post['ratingsTotal'] ?? 0) as int;
        final prevPostCount = (post['ratingsCount'] ?? 0) as int;

        // === CALC ===
        final newTotal     = prevTotal + intVal;
        final newCount     = prevCount + 1;
        final newAvg       = (newCount == 0) ? 0.0 : newTotal / newCount;

        final newPostTotal = prevPostTotal + intVal;
        final newPostCount = prevPostCount + 1;
        final newPostAvg   = newPostTotal / newPostCount;

        // === WRITES หลังจากอ่านครบแล้ว ===
        tx.set(ratingRef, {
          'value': intVal,
          'at': FieldValue.serverTimestamp(),
        });

        tx.set(ownerRef, {
          'starsTotal': newTotal,
          'starsRaters': newCount,
          'starsCount': double.parse(newAvg.toStringAsFixed(1)),
        }, SetOptions(merge: true));

        tx.update(postRef, {
          'ratingsTotal': newPostTotal,
          'ratingsCount': newPostCount,
          'ratingAvg': double.parse(newPostAvg.toStringAsFixed(2)),
        });
      });
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? 'ให้คะแนนไม่สำเร็จ (สิทธิ์ไม่ผ่าน)');
    } catch (e) {
      throw Exception('ให้คะแนนไม่สำเร็จ: $e');
    }
  }
} 


Future<void> ratePost({
  required String postId,
  required String ownerId,   // uid เจ้าของโพสต์
  required int value,        // 1..5
  String? comment,
}) async {
  final fs  = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final postRef        = fs.collection('posts').doc(postId);
  final postRatingRef  = postRef.collection('ratings').doc(uid);
  final userRatingRef  = fs.collection('users').doc(ownerId).collection('ratings').doc();
  final publicUserRatingRef = fs.collection('publicUsers').doc(ownerId).collection('ratings').doc();

  // อ่านค่าปัจจุบันเพื่อคำนวณสรุปให้ตรงกับ rules
  final postSnap = await postRef.get();
  if (!postSnap.exists) throw 'Post not found';

  final data = postSnap.data()!;
  final prevTotal = (data['ratingsTotal'] ?? 0) * 1.0;
  final prevCount = (data['ratingsCount'] ?? 0) * 1.0;

  // กันรีวิวซ้ำ
  final exist = await postRatingRef.get();
  if (exist.exists) throw 'คุณรีวิวโพสต์นี้ไปแล้ว';

  final newTotal = prevTotal + value;
  final newCount = prevCount + 1;
  final newAvg   = newTotal / newCount;

  final batch = fs.batch();

  // 1) ใส่เอกสารเรตติ้งของโพสต์ (ให้ผ่านเงื่อนไข existsAfter ของ rules)
  batch.set(postRatingRef, {
    'value'    : value,
    'at'       : FieldValue.serverTimestamp(),
    if (comment != null && comment.isNotEmpty) 'comment': comment,
    'ownerId'  : ownerId,
    'postTitle': data['title'] ?? '',
  });

  // 2) อัปเดตรวมของโพสต์ (ต้องเป็นค่าที่คำนวณตรง)
  batch.update(postRef, {
    'ratingsTotal': newTotal,
    'ratingsCount': newCount,
    'ratingAvg'   : newAvg,
  });

  // 3) mirror ไปกล่องรีวิวของเจ้าของโพสต์ (users/…/ratings)
  batch.set(userRatingRef, {
    'value'    : value,
    'at'       : FieldValue.serverTimestamp(),
    'comment'  : comment ?? '',
    'postId'   : postId,
    'postTitle': data['title'] ?? '',
    'raterId'  : uid,
  });

  // 4) mirror สาธารณะ (publicUsers/…/ratings) เพื่อให้คนอื่นอ่านได้
  batch.set(publicUserRatingRef, {
    'value'    : value,
    'at'       : FieldValue.serverTimestamp(),
    'comment'  : comment ?? '',
    'postId'   : postId,
    'postTitle': data['title'] ?? '',
    'raterId'  : uid,
  });

  await batch.commit();
}
