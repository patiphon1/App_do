import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../widgets/user_reviews_sheet.dart';
import '../../../widgets/post_reviews_sheet.dart';

class ProfileViewPage extends StatelessWidget {
  const ProfileViewPage({super.key, this.viewUid});

  /// ถ้าส่ง uid มาจะเปิดโปรไฟล์ของคนนั้น
  /// ถ้าไม่ส่ง จะเปิดโปรไฟล์ของตัวเอง
  final String? viewUid;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final targetUid = viewUid ?? currentUid;
    if (targetUid == null) {
      return const Scaffold(body: Center(child: Text('ยังไม่ได้ล็อกอิน')));
    }

    final userDocStream =
        FirebaseFirestore.instance.collection('users').doc(targetUid).snapshots();
    final postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: targetUid)
        .snapshots();

    final viewingSelf = targetUid == currentUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
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
          final photoURL = u['photoURL'] as String?;
          final stars = (u['starsCount'] ?? 0).toDouble(); // 0–5
          final verified = (u['verified'] ?? false) == true;
          final targetRole = u['role'] as String?; // role ของคนที่กำลังดูอยู่

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + verified overlay
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: (photoURL != null && photoURL.isNotEmpty)
                                ? NetworkImage(photoURL)
                                : null,
                            child: (photoURL == null || photoURL.isEmpty)
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                          if (verified)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified, size: 18, color: Color(0xFF2ECC71)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      Expanded(
  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: viewingSelf
        ? FirebaseFirestore.instance.doc('users/$currentUid').snapshots()
        : const Stream.empty(),
    builder: (context, meSnap) {
      final meRole = viewingSelf ? (meSnap.data?.data()?['role'] as String?) : null;
      final showOnlyAdmin = viewingSelf && meRole == 'admin';

      // ====== ถ้าเป็นแอดมินและกำลังดูโปรไฟล์ตัวเอง -> โชว์ "เฉพาะเมนูแอดมิน" ======
      if (showOnlyAdmin) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ชื่อ + badge verified (อยากคงหัวเรื่องไว้ให้รู้ว่าเป็นใคร)
            Row(
              children: [
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                if (verified) _verifiedBadge(),
              ],
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.admin_panel_settings, size: 18),
                        SizedBox(width: 8),
                        Text('Admin tools', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/admin'),
                          icon: const Icon(Icons.verified),
                          label: const Text('อนุมัติยืนยันตัวตน'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/admin/users'),
                          icon: const Icon(Icons.manage_accounts),
                          label: const Text('จัดการสิทธิ์ผู้ใช้'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      // ====== ผู้ใช้ทั่วไป หรือแอดมินที่กำลังดูโปรไฟล์ "คนอื่น" -> โชว์ UI ปกติ ======
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ชื่อ + badge verified
          Row(
            children: [
              Text(
                displayName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              if (verified) _verifiedBadge(),
            ],
          ),
          const SizedBox(height: 8),

          // สถิติ: จำนวนโพสต์ + ดาวเฉลี่ย
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: postsStream,
            builder: (context, postSnap) {
              final postCount = postSnap.data?.docs.length ?? 0;

              Widget stat(String label, Widget valueWidget) => Column(
                    children: [
                      valueWidget,
                      const SizedBox(height: 2),
                      Text(label),
                    ],
                  );

              Widget starRow(double rating) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(5, (i) {
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
                    const SizedBox(width: 6),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  stat(
                    'โพสต์',
                    Text(
                      '$postCount',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  stat('เรตติ้ง', starRow(stars)),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // ปุ่มแก้ไขโปรไฟล์ (เฉพาะเจ้าตัวเอง)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      viewingSelf ? () => Navigator.pushNamed(context, '/profile/edit') : null,
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

          // ถ้าแอดมินดูโปรไฟล์ "คนอื่น" แสดง role ของเป้าหมายไว้เล็กน้อย
          if (!viewingSelf && (targetRole?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text('role: $targetRole', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      );
    },
  ),
),

                    ],
                  ),
                ),
              ),

              // bio
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(bio, style: const TextStyle(height: 1.3)),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // รีวิวผู้ใช้
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: Icon(Icons.grid_on_rounded, size: 20)),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => UserReviewsSheet(
                            userId: targetUid,
                            displayName: displayName,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.person_pin_outlined, size: 20, color: Colors.blueGrey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),

              // Grid โพสต์ (แตะเพื่อดูรีวิวของโพสต์นั้น)
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 1,
                        crossAxisSpacing: 1,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final doc = docs[i];
                          final p = doc.data();
                          final url = p['imageUrl'] as String?;
                          return GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => PostReviewsSheet(
                                postId: doc.id,
                                postTitle: p['title'] ?? '',
                                postImageUrl: url,
                              ),
                            ),
                            child: Container(
                              color: Colors.grey[200],
                              child: (url != null && url.isNotEmpty)
                                  ? Image.network(url, fit: BoxFit.cover)
                                  : const Icon(Icons.image_not_supported_outlined),
                            ),
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

/// Badge “ยืนยันตัวตนแล้ว”
Widget _verifiedBadge() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFE9F7EF),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFF2ECC71)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified, size: 16, color: Color(0xFF2ECC71)),
        SizedBox(width: 4),
        Text(
          'ยืนยันตัวตนแล้ว',
          style: TextStyle(
            color: Color(0xFF1E8449),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
