import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> showRatePostDialog(BuildContext context, {required String postId}) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  int value = 5;
  final controller = TextEditingController();
  bool submitting = false;

  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('ให้คะแนนโพสต์'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => IconButton(
                onPressed: submitting ? null : () => setState(() => value = i + 1),
                icon: Icon(i < value ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
              )),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              enabled: !submitting,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'พิมพ์รีวิว (ไม่บังคับ)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: submitting ? null : () async {
              setState(() => submitting = true);
              try {
                final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
                final postSnap = await postRef.get(); // อ่านนอกทรานแซกชันได้
                final ownerId   = postSnap.data()?['userId'] as String?;
                final postTitle = (postSnap.data()?['title'] ?? '') as String? ?? '';
                if (ownerId == null) throw Exception('ไม่พบเจ้าของโพสต์');
                if (ownerId == uid)  throw Exception('ห้ามให้คะแนนโพสต์ของตัวเอง');

                final comment = controller.text.trim();

                await FirebaseFirestore.instance.runTransaction((tx) async {
                  final ratingRef = postRef.collection('ratings').doc(uid);
                  final ownerRef  = FirebaseFirestore.instance.collection('users').doc(ownerId);

                  // ---------- READS (ทั้งหมดก่อน) ----------
                  final post = await tx.get(postRef);
                  final owner = await tx.get(ownerRef);
                  final rated = await tx.get(ratingRef);

                  if (!post.exists) throw Exception('โพสต์ถูกลบหรือไม่พบ');
                  if (rated.exists) throw Exception('คุณได้ให้คะแนนโพสต์นี้ไปแล้ว');

                  final tPost  = (post.data()?['ratingsTotal'] ?? 0) as num;
                  final cPost  = (post.data()?['ratingsCount'] ?? 0) as num;
                  final tUser  = (owner.data()?['starsTotal']  ?? 0) as num;
                  final cUser  = (owner.data()?['starsRaters'] ?? 0) as num;

                  final newPostTotal = tPost + value;
                  final newPostCount = cPost + 1;
                  final newUserTotal = tUser + value;
                  final newUserCount = cUser + 1;

                  // ---------- WRITES (หลังจากอ่านครบ) ----------
                  tx.set(ratingRef, {
                    'value': value,
                    'at': FieldValue.serverTimestamp(),
                    if (comment.isNotEmpty) 'comment': comment,
                    'ownerId': ownerId,
                    'postTitle': postTitle,
                  });

                  tx.update(postRef, {
                    'ratingsTotal': newPostTotal,
                    'ratingsCount': newPostCount,
                    'ratingAvg': newPostTotal / newPostCount,
                  });

                  tx.set(ownerRef, {
                    'starsTotal': newUserTotal,
                    'starsRaters': newUserCount,
                    'starsCount': newUserTotal / newUserCount,
                  }, SetOptions(merge: true));

                  // mirror ไปที่ users/{ownerId}/ratings/{uid}
                  tx.set(ownerRef.collection('ratings').doc('${uid}_$postId'), {
                    'value': value,
                    'at': FieldValue.serverTimestamp(),
                    if (comment.isNotEmpty) 'comment': comment,
                    'postId': postId,
                    'postTitle': postTitle,
                    'raterId': uid, // สำคัญ: ให้ตรงกับกฎ
                  });
                });

                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ให้คะแนนไม่สำเร็จ: $e')),
                  );
                }
              } finally {
                if (context.mounted) setState(() => submitting = false);
              }
            },
            child: const Text('ให้คะแนน'),
          ),
        ],
      ),
    ),
  );
}
