import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ให้คะแนนโพสต์แบบ atomic ด้วย batch:
/// - posts/{postId}: ratingsTotal/ratingsCount/ratingAvg (เพิ่มขึ้นเท่านั้น)
/// - posts/{postId}/ratings/{raterUid}: เอกสารเรตติ้ง (exists เพื่อผ่าน rules ของโพสต์)
/// - users/{ownerId}: starsTotal/starsRaters/starsCount (เพิ่มขึ้นเท่านั้น)
/// - users/{ownerId}/ratings/{...}: mirror (อ่านได้เฉพาะ owner/admin)
/// - publicUsers/{ownerId}/ratings/{...}: mirror สาธารณะ (ทุกคนอ่านได้)
/// - publicUsers/{ownerId}.ratingCount: +1 (ใช้ทำ Leaderboard)
Future<void> ratePost({
  required String postId,
  required String ownerId,
  required int value,          // 1..5
  String? comment,
}) async {
  final fs  = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final postRef       = fs.collection('posts').doc(postId);
  final postRatingRef = postRef.collection('ratings').doc(uid);

  final ownerRef      = fs.collection('users').doc(ownerId);
  final userRatingRef = ownerRef.collection('ratings').doc('${uid}_$postId');

  final pubUserRef    = fs.collection('publicUsers').doc(ownerId);
  final pubUserRatingRef = pubUserRef.collection('ratings').doc();

  // ---- READS ----
  final postSnap = await postRef.get();
  if (!postSnap.exists) {
    throw 'ไม่พบโพสต์ (อาจถูกลบไปแล้ว)';
  }
  final post = postSnap.data()!;

  if (ownerId == uid) throw 'ห้ามให้คะแนนโพสต์ของตัวเอง';

  // กันรีวิวซ้ำ
  final existed = await postRatingRef.get();
  if (existed.exists) throw 'คุณรีวิวโพสต์นี้ไปแล้ว';

  final postTotal0 = (post['ratingsTotal'] ?? 0) * 1.0;
  final postCount0 = (post['ratingsCount'] ?? 0) * 1.0;

  // อ่านคะแนนรวมของเจ้าของโพสต์
  final ownerSnap = await ownerRef.get();
  final owner = ownerSnap.data() ?? <String, dynamic>{};
  final ownerTotal0  = (owner['starsTotal']  ?? 0) * 1.0;
  final ownerCount0  = (owner['starsRaters'] ?? 0) * 1.0;

  final postTotal1 = postTotal0 + value;
  final postCount1 = postCount0 + 1;
  final postAvg1   = postTotal1 / postCount1;

  final ownerTotal1 = ownerTotal0 + value;
  final ownerCount1 = ownerCount0 + 1;
  final ownerAvg1   = ownerTotal1 / ownerCount1;

  final commentTrim = (comment ?? '').trim();

  // ---- BATCH WRITES ----
  final batch = fs.batch();

  // 1) เอกสารเรตติ้งของโพสต์ (ให้ผ่าน existsAfter)
  batch.set(postRatingRef, {
    'value'    : value,
    'at'       : FieldValue.serverTimestamp(),
    if (commentTrim.isNotEmpty) 'comment': commentTrim,
    'ownerId'  : ownerId,
    'postTitle': post['title'] ?? '',
    'raterId'  : uid,
  });

  // 2) อัปเดตรวมของโพสต์
  batch.update(postRef, {
    'ratingsTotal': postTotal1,
    'ratingsCount': postCount1,
    'ratingAvg'   : postAvg1,
  });

  // 3) อัปเดตรวมของเจ้าของโพสต์
  batch.set(ownerRef, {
    'starsTotal'  : ownerTotal1,
    'starsRaters' : ownerCount1,
    'starsCount'  : ownerAvg1,
  }, SetOptions(merge: true));

  // 4) mirror ส่วนตัว (users/{owner}/ratings)
  batch.set(userRatingRef, {
    'value'    : value,
    'at'       : FieldValue.serverTimestamp(),
    'comment'  : commentTrim,
    'postId'   : postId,
    'postTitle': post['title'] ?? '',
    'raterId'  : uid,
  });

  // 5) mirror สาธารณะ (publicUsers/{owner}/ratings) + นับรีวิวเพื่อ Leaderboard
  batch.set(pubUserRatingRef, {
    'value'    : value,
    'at'       : FieldValue.serverTimestamp(),
    'comment'  : commentTrim,
    'postId'   : postId,
    'postTitle': post['title'] ?? '',
    'raterId'  : uid,
  });
  batch.set(pubUserRef, {
    'ratingCount': FieldValue.increment(1),
    'updatedAt'  : FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  await batch.commit();
}
