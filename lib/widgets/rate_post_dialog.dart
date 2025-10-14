import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/rating_service.dart'; 

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
                // อ่าน ownerId แยกก่อนเพื่อส่งเข้า ratePost(...)
                final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
                final snap = await postRef.get();
                final ownerId = snap.data()?['userId'] as String?;
                if (ownerId == null) throw 'ไม่พบเจ้าของโพสต์';
                if (ownerId == uid)  throw 'ห้ามให้คะแนนโพสต์ของตัวเอง';

                await ratePost(
                  postId: postId,
                  ownerId: ownerId,
                  value: value,
                  comment: controller.text,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ให้คะแนนสำเร็จ')),
                  );
                }
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
