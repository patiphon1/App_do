// lib/features/profile/pages/profile_view_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileViewPage extends StatelessWidget {
  const ProfileViewPage({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final usersDoc =
        FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
    final postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: _uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: usersDoc,
        builder: (context, userSnap) {
          if (userSnap.hasError) {
            return const Center(child: Text('โหลดโปรไฟล์ไม่สำเร็จ'));
          }
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final u = userSnap.data!.data() ?? {};
          final displayName = (u['displayName'] ?? 'ผู้ใช้') as String;
          final bio = (u['bio'] ?? '') as String;
          final photoUrl = u['photoUrl'] as String?;
          final stars = (u['starsCount'] ?? 0).toDouble(); // ⭐ 0–5 คะแนน

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: (photoUrl != null &&
                                photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      const SizedBox(width: 16),

                      // Stats + Buttons
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ✅ Stats: โพสต์ + ดาว (เต็ม 5 ดวง)
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: postsStream,
                              builder: (context, postSnap) {
                                final postCount = postSnap.data?.docs.length ?? 0;

                                Widget stat(String label, Widget valueWidget) =>
                                    Column(
                                  children: [
                                    valueWidget,
                                    const SizedBox(height: 2),
                                    Text(label),
                                  ],
                                );

                                // ฟังก์ชันสร้างดาวเต็ม 5 ดวง
                                Widget starRow(double rating) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(5, (i) {
                                      final filled = rating >= i + 1;
                                      final half = !filled && rating > i && rating < i + 1;
                                      return Icon(
                                        filled
                                            ? Icons.star_rounded
                                            : half
                                                ? Icons.star_half_rounded
                                                : Icons.star_border_rounded,
                                        color: Colors.amber,
                                        size: 22,
                                      );
                                    }),
                                  );
                                }

                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    stat(
                                        'โพสต์',
                                        Text('$postCount',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18))),
                                    stat('เรตติ้ง', starRow(stars)),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pushNamed(
                                        context, '/profile/edit'),
                                    child: const Text('แก้ไขโปรไฟล์'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () {},
                                  child: const Icon(Icons.more_horiz_rounded),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bio
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(bio, style: const TextStyle(height: 1.3)),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Tabs (เฉพาะโพสต์)
              const SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child:
                            Center(child: Icon(Icons.grid_on_rounded, size: 20)),
                      ),
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: .4,
                        child: Center(
                            child: Icon(Icons.person_pin_outlined, size: 20)),
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),

              // ✅ โพสต์ (เรียง createdAt ฝั่ง client)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: postsStream,
                builder: (context, postSnap) {
                  if (postSnap.hasError) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('โหลดโพสต์ไม่สำเร็จ')),
                      ),
                    );
                  }
                  if (!postSnap.hasData) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final docs = [...postSnap.data!.docs];
                  docs.sort((a, b) {
                    final ta = a.data()['createdAt'];
                    final tb = b.data()['createdAt'];
                    if (ta is! Timestamp && tb is! Timestamp) return 0;
                    if (ta is! Timestamp) return 1;
                    if (tb is! Timestamp) return -1;
                    return tb.compareTo(ta);
                  });

                  if (docs.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('ยังไม่มีโพสต์')),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.all(1),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 1,
                        crossAxisSpacing: 1,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final p = docs[i].data();
                          final url = p['imageUrl'] as String?;
                          return Container(
                            color: Colors.grey[200],
                            child: (url != null && url.isNotEmpty)
                                ? Image.network(url, fit: BoxFit.cover)
                                : const Icon(Icons.image_not_supported_outlined),
                          );
                        },
                        childCount: docs.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
