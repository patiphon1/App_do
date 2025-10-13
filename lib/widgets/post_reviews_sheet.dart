import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostReviewsSheet extends StatelessWidget {
  final String postId;
  final String? postTitle;
  final String? postImageUrl;
  const PostReviewsSheet({
    super.key,
    required this.postId,
    this.postTitle,
    this.postImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final ratingsQuery = FirebaseFirestore.instance
        .collection('posts').doc(postId)
        .collection('ratings')
        .orderBy('at', descending: true);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
              ListTile(
                leading: (postImageUrl != null && postImageUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(postImageUrl!, width: 44, height: 44, fit: BoxFit.cover))
                    : const Icon(Icons.image),
                title: Text('รีวิวของโพสต์: ${postTitle ?? ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ratingsQuery.snapshots(),
                  builder: (_, snap) {
                    if (snap.hasError) return const Center(child: Text('โหลดรีวิวไม่สำเร็จ'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('ยังไม่มีรีวิว'));

                    return ListView.separated(
                      controller: controller,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = docs[i].data();
                        final v = (d['value'] ?? 0) as int;
                        final comment = (d['comment'] ?? '') as String;
                        final images = (d['images'] as List?)?.cast<String>() ?? const <String>[];
                        final ts = d['at'];
                        String when = '';
                        if (ts is Timestamp) {
                          final dt = ts.toDate();
                          when =
                              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        }

                        return ListTile(
                          title: Row(
                            children: [
                              ...List.generate(5, (j) => Icon(
                                j < v ? Icons.star_rounded : Icons.star_border_rounded,
                                color: Colors.amber, size: 20,
                              )),
                              const SizedBox(width: 8),
                              Text('$v/5 · $when', style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(comment),
                              ],
                              if (images.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8, runSpacing: 8,
                                  children: images.map((u) => GestureDetector(
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: InteractiveViewer(child: Image.network(u, fit: BoxFit.contain)),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(u, width: 72, height: 72, fit: BoxFit.cover),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
