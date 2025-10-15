// lib/features/auth/pages/profile_view_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../widgets/user_reviews_sheet.dart';
import '../../../widgets/post_reviews_sheet.dart';
import '../../../services/user_doc.dart';
import '../../../widgets/curved_nav_scaffold.dart';

class ProfileViewPage extends StatelessWidget {
  const ProfileViewPage({super.key, this.viewUid});

  /// ถ้าส่ง uid -> เปิดโปรไฟล์คนนั้น / ไม่ส่ง -> ของตัวเอง
  final String? viewUid;
  
  Future<void> _onBottomTap(BuildContext context, int i) async {
    switch (i) {
      case 0: Navigator.pushReplacementNamed(context, '/home'); break;
      case 1: Navigator.pushReplacementNamed(context, '/leaderboard'); break;
      case 2: Navigator.pushNamed(context, '/createPost'); break; // ปุ่มกลาง
      case 3: Navigator.pushReplacementNamed(context, '/chat'); break;
      case 4: /* อยู่หน้าโปรไฟล์แล้ว */ break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final targetUid = viewUid ?? currentUid;
    if (targetUid == null) {
      return const Scaffold(body: Center(child: Text('ยังไม่ได้ล็อกอิน')));
    }

    final viewingSelf = targetUid == currentUid;

    // ✅ สลับ source อัตโนมัติตามสิทธิ์
    final userDocStream = UserDoc.streamForView(targetUid);

    // โพสต์ของเจ้าของโปรไฟล์
    final postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: targetUid)
        .snapshots();

    return CurvedNavScaffold(
      currentIndex: 4,                 // โปรไฟล์ = index 4
      onTap: (i) => _onBottomTap(context, i),
      // ถ้ามีหน้าก่อนหน้า -> แสดงลูกศร ย้อนกลับได้; ถ้าไม่มี -> ไม่แสดง (กันจอดำ)
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  final popped = await Navigator.maybePop(context);
                  if (!popped && context.mounted) {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
              )
            : null,
        title: const Text('โปรไฟล์', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      bodyBuilder: (context) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, userSnap) {
            if (userSnap.hasError) {
              return const Center(child: Text('โหลดโปรไฟล์ไม่สำเร็จ'));
            }
            if (!userSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final u = userSnap.data!.data() ?? {};

            // publicUsers จะมีเฉพาะฟิลด์ public
            final displayName = (u['displayName'] ?? 'ผู้ใช้') as String;
            final photoURL = u['photoURL'] as String?;
            final verified = (u['verified'] ?? false) == true;

            // สถิติ
            final stars = (u['starsCount'] ?? 0).toDouble();

            // ฟิลด์ private แสดงเฉพาะตอนดูตัวเอง (หรือถ้า source เป็น users/* จากสิทธิ์แอดมิน)
            final bio = viewingSelf ? (u['bio'] ?? '') as String : '';
            final targetRole = viewingSelf ? u['role'] as String? : null;

            // ✅ นิยาม isAdmin: ดูเฉพาะตอนดูตัวเอง และ role เป็น admin
            final isAdmin = viewingSelf && (targetRole == 'admin');

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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ชื่อ + badge verified
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (verified) _verifiedBadge(),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // จำนวนโพสต์ + ดาวเฉลี่ย
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

                              // ▶️ ปุ่มแก้ไขโปรไฟล์ + เมนูสามจุด (เฉพาะผู้ใช้ทั่วไป ไม่ใช่แอดมิน)
                              if (viewingSelf && !isAdmin) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.edit),
                                        label: const Text('แก้ไขโปรไฟล์'),
                                        onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_horiz_rounded),
                                      onSelected: (value) async {
                                        switch (value) {
                                          case 'logout':
                                            try {
                                              await FirebaseAuth.instance.signOut();
                                              if (!context.mounted) return;
                                              // เคลียร์สแต็กแล้วไปหน้า login (เปลี่ยนเป็น route ของคุณได้)
                                              Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('ออกจากระบบไม่สำเร็จ: $e')),
                                              );
                                            }
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem<String>(
                                          value: 'logout',
                                          child: Row(
                                            children: [
                                              Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                                              SizedBox(width: 8),
                                              Text('ออกจากระบบ', style: TextStyle(color: Colors.redAccent)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],

                              // ▶️ ปุ่มลัดให้ดาวจากโพสต์ล่าสุด (เฉพาะตอนดูคนอื่น และมีโพสต์)
                              if (!viewingSelf) ...[
                                const SizedBox(height: 8),
                                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: postsStream,
                                  builder: (context, ps) {
                                    final docs = ps.data?.docs ?? const [];
                                    if (docs.isEmpty) return const SizedBox.shrink();
                                    final last = docs.first; // สมมติเรียงล่าสุดใน UI แล้ว
                                    final p = last.data();
                                    final title = (p['title'] ?? '') as String? ?? '';
                                    final url = p['imageUrl'] as String?;
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      // คุณสามารถเพิ่มปุ่ม action ตรงนี้ภายหลังได้
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  },
                                ),
                              ],

                              // ▶️ แผง Admin tools: โชว์เฉพาะแอดมิน
                              if (isAdmin) ...[
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
                                            Text('Admin tools',
                                                style: TextStyle(fontWeight: FontWeight.w700)),
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

                              // (ออปชั่น) แสดง role เมื่อดูตัวเอง (ผู้ใช้ทั่วไปเท่านั้น)
                              if (viewingSelf && !isAdmin && (targetRole?.isNotEmpty ?? false)) ...[
                                const SizedBox(height: 8),
                                Text('role: $targetRole',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ▶️ bio (publicUsers ไม่มี bio) — แสดงเฉพาะผู้ใช้ทั่วไป
                if (viewingSelf && !isAdmin) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(bio, style: const TextStyle(height: 1.3)),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],

                // ▶️ ปุ่มเปิดรีวิวรวมของผู้ใช้ — ซ่อนถ้าเป็นแอดมิน
                if (!isAdmin)
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
                              useSafeArea: true,
                              showDragHandle: true,
                              enableDrag: true,
                              builder: (_) => FractionallySizedBox(
                                heightFactor: 0.6,
                                child: UserReviewsSheet(
                                  userId: targetUid,
                                  displayName: displayName,
                                ),
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

                // Grid โพสต์ (แตะเพื่อให้ดาว/รีวิวโพสต์นั้น) — แสดงทุกคนตามเดิม
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
                                useSafeArea: true,
                                showDragHandle: true,
                                enableDrag: true,
                                builder: (_) => FractionallySizedBox(
                                  heightFactor: 0.6,
                                  child: PostReviewsSheet(
                                    postId: doc.id,
                                    postTitle: p['title'] ?? '',
                                    postImageUrl: url,
                                  ),
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
        );
      },
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
            fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
