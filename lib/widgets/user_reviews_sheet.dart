import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserReviewsSheet extends StatelessWidget {
  const UserReviewsSheet({
    super.key,
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ratings')
        .orderBy('at', descending: true);

    // ⛔️ ไม่ใช้ Scaffold — ให้เป็นคอนเทนต์ของ BottomSheet
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('รีวิว: $displayName',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // เนื้อหาเลื่อนภายใน
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: q.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(child: Text('โหลดรีวิวไม่สำเร็จ'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('ยังไม่มีรีวิว'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = docs[i].data();
                      final value = (m['value'] ?? 0) as int;
                      final comment = (m['comment'] ?? '') as String;
                      final at = (m['at'] as Timestamp?)?.toDate();
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Row(
                          children: [
                            ...List.generate(
                              5,
                              (idx) => Icon(
                                idx < value
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: Colors.amber, size: 18,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('$value/5',
                                style: const TextStyle(fontSize: 12)),
                            if (at != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                at.toLocal().toString().substring(0, 19),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ],
                        ),
                        subtitle: (comment.isNotEmpty)
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(comment),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
