import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../widgets/curved_nav_scaffold.dart';
import 'profile_view_page.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  Future<void> _onBottomTap(BuildContext context, int i) async {
    switch (i) {
      case 0: Navigator.pushReplacementNamed(context, '/home'); break;
      case 1: break;
      case 2: Navigator.pushNamed(context, '/createPost'); break;
      case 3: Navigator.pushReplacementNamed(context, '/chat'); break;
      case 4: Navigator.pushReplacementNamed(context, '/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('publicUsers')
        .orderBy('ratingCount', descending: true)
        .limit(100)
        .snapshots();

    return CurvedNavScaffold(
      currentIndex: 1,
      onTap: (i) => _onBottomTap(context, i),
      appBar: AppBar(title: const Text('🏆 Leaderboard', style: TextStyle(fontWeight: FontWeight.w800))),
      bodyBuilder: (context) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text('โหลดไม่สำเร็จ'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('ยังไม่มีการรีวิว'));

            final top = docs.take(3).toList();
            final rest = docs.skip(3).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final cardWidth = (width - 32) / 3;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFFEEF5FF), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE3ECFF)),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (top.length >= 2)
                                SizedBox(width: cardWidth, child: _TopCard(rank: 2, doc: top[1])),
                              if (top.isNotEmpty)
                                SizedBox(width: cardWidth, child: _TopCard(rank: 1, doc: top[0], big: true)),
                              if (top.length >= 3)
                                SizedBox(width: cardWidth, child: _TopCard(rank: 3, doc: top[2])),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
                    child: Text('อันดับถัดไป',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
                SliverList.separated(
                  itemCount: rest.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = rest[i];
                    final m = d.data();
                    final rank = i + 4;
                    final name = (m['displayName'] ?? 'ไม่ระบุ').toString();
                    final photo = (m['photoURL'] ?? '').toString();
                    final verified = (m['verified'] ?? false) == true;
                    final count = (m['ratingCount'] ?? 0) as int;

                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileViewPage(viewUid: d.id)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            _RankPill(rank: rank),
                            const SizedBox(width: 10),
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                  child: photo.isEmpty ? const Icon(Icons.person) : null,
                                ),
                                if (verified)
                                  const Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Icon(Icons.verified, size: 16, color: Colors.green),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 10),
                            _ChipStat(icon: Icons.reviews, label: '$count รีวิว'),
                          ],
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

class _TopCard extends StatelessWidget {
  const _TopCard({required this.rank, required this.doc, this.big = false});
  final int rank;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final name = (m['displayName'] ?? 'ไม่ระบุ').toString();
    final photo = (m['photoURL'] ?? '').toString();
    final verified = (m['verified'] ?? false) == true;
    final count = (m['ratingCount'] ?? 0) as int;

    final medal = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    final avatarRadius = big ? 30.0 : 26.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileViewPage(viewUid: doc.id)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty ? const Icon(Icons.person, size: 30) : null,
              ),
              if (verified)
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: Icon(Icons.verified, size: 16, color: Colors.green),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: medal, size: 18),
              const SizedBox(width: 4),
              Text('$count บริจาค', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final bg = rank <= 10 ? const Color(0xFFEFF6FF) : const Color(0xFFF2F2F2);
    final fg = rank <= 10 ? const Color(0xFF1565D8) : Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('#$rank', style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}

class _ChipStat extends StatelessWidget {
  const _ChipStat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EBFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF5B8DEF)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
