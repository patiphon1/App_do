import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/server_clock.dart';
import '../app_gate.dart'; // กลับไป Gate หลัง logout
import 'features/auth/pages/create_post_page.dart';

//  เพิ่ม import สำหรับแชท
import 'features/chat/chat_p2p_page.dart';
import 'services/chat_service.dart';

/// -------------------------- Model --------------------------
enum PostTag { announce, donate, swap }
PostTag _tagFrom(String? s) =>
    switch (s) { 'donate' => PostTag.donate, 'swap' => PostTag.swap, _ => PostTag.announce };
String _tagTo(PostTag t) =>
    switch (t) { PostTag.donate => 'donate', PostTag.swap => 'swap', PostTag.announce => 'announce' };

// ✅ helper สำหรับแปลง Tag -> kind ที่ใช้ในแชท
String _kindFromTag(PostTag t) {
  switch (t) {
    case PostTag.donate:
      return 'donate';
    case PostTag.swap:
      return 'swap';
    case PostTag.announce:
    default:
      // ถ้าเป็นประกาศ จะไปที่หมวดบริจาคเป็นค่าเริ่ม (ปรับได้ตามต้องการ)
      return 'donate';
  }
}

class Post {
  final String id;
  final String userId;        // ✅ เพิ่ม (เจ้าของโพสต์)
  final String userName;
  final String userAvatar;    // URL
  final String title;
  final String? imageUrl;     // URL
  final PostTag tag;
  final int comments;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.userId,     // ✅
    required this.userName,
    required this.userAvatar,
    required this.title,
    required this.tag,
    required this.comments,
    required this.createdAt,
    this.imageUrl,
  });

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Post(
      id: doc.id,
      userId: d['userId'] ?? '',            // ✅ ต้องมีใน posts
      userName: d['userName'] ?? '',
      userAvatar: d['userAvatar'] ?? '',
      title: d['title'] ?? '',
      imageUrl: d['imageUrl'],
      tag: _tagFrom(d['tag']),
      comments: (d['comments'] ?? 0) as int,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// ------------------------------ Home Page ------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController(text: '');
  final _scroll = ScrollController();
  final _col = FirebaseFirestore.instance.collection('posts');

  List<Post> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _loadingMore = false;
  int _notif = 2;
  int _tab = 0;
  int _activeFilters = 0;
  PostTag? _selectedTag;

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _cursor == null) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Query<Map<String, dynamic>> _baseQuery() {
    final now = ServerClock.now();

    Query<Map<String, dynamic>> q = _col
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt'); // เหลืออันเดียว จะไม่ต้องใช้ composite index

    if (_selectedTag != null) {
      q = q.where('tag', isEqualTo: _tagTo(_selectedTag!));
    }
    final s = _search.text.trim().toLowerCase();
    if (s.isNotEmpty) {
      q = q.where('titleKeywords', arrayContains: s);
    }
    return q;
  }

  Future<void> _loadFirst() async {
    setState(() => _loading = true);
    try {
      final snap = await _baseQuery().limit(10).get();
      setState(() {
        _items = snap.docs.map(Post.fromDoc).toList();
        _cursor = snap.docs.isNotEmpty ? snap.docs.last : null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await _baseQuery().startAfterDocument(_cursor!).limit(10).get();
      setState(() {
        _items.addAll(snap.docs.map(Post.fromDoc));
        _cursor = snap.docs.isNotEmpty ? snap.docs.last : null;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    _cursor = null;
    await _loadFirst();
  }

  void _openFilter() async {
    final sel = await showModalBottomSheet<PostTag?>(
      context: context,
      showDragHandle: true,
      builder: (_) => _FilterSheet(selected: _selectedTag),
    );
    if (sel == null && _selectedTag == null) return;
    setState(() {
      _selectedTag = sel;
      _activeFilters = sel == null ? 0 : 1;
    });
    _loadFirst();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AppGate()),
                  (route) => false,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logout failed: $e')),
                );
              }
            },
          ),
        ],
      ),

      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostPage()),
          );
          if (created == true) {
            _onRefresh();
          }
        },
        elevation: 2,
        child: const Icon(Icons.add, size: 28),
      ),

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          children: [
            _NavIcon(icon: Icons.home_rounded,   active: _tab == 0, onTap: ()=> setState(()=> _tab=0)),
            _NavIcon(icon: Icons.notifications_rounded, badge: _notif, active: _tab == 1, onTap: ()=> setState(()=> _tab=1)),
            const Spacer(),
            _NavIcon(
              icon: Icons.chat_bubble_rounded,
              active: _tab == 3,
              onTap: () => Navigator.pushNamed(context, '/chat'),
            ),
           _NavIcon(
              icon: Icons.person_rounded,
              active: _tab == 4,
              onTap: () {
                setState(() => _tab = 4);
                Navigator.pushNamed(context, '/profile');
              },
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _loadFirst(),
                          decoration: InputDecoration(
                            hintText: 'Search',
                            prefixIcon: const Icon(Icons.search_rounded),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F6F7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _FilterButton(badge: _activeFilters, onTap: _openFilter),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_items.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('No posts found')),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _PostCard(post: _items[i]),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 80,
                  child: Center(
                    child: _loadingMore
                        ? const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: CircularProgressIndicator(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------ Widgets ------------------------------
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.selected});
  final PostTag? selected;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  PostTag? _sel;
  @override
  void initState() {
    super.initState();
    _sel = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('All', _sel == null, () => setState(()=> _sel = null)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              _chip('ประกาศ', _sel == PostTag.announce, ()=> setState(()=> _sel = PostTag.announce)),
              _chip('บริจาค', _sel == PostTag.donate,   ()=> setState(()=> _sel = PostTag.donate)),
              _chip('แลกเปลี่ยน', _sel == PostTag.swap,   ()=> setState(()=> _sel = PostTag.swap)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: ()=> Navigator.pop(context, _sel),
              child: const Text('Apply filter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onTap, this.badge});
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final hasBadge = (badge ?? 0) > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Filter'),
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (hasBadge)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              child: Center(
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(post.userId)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Icon(Icons.person);
                    }
                    final data = snap.data!.data();
                    final url = data?['photoUrl'] as String?;
                    if (url == null || url.isEmpty) {
                      return const Icon(Icons.person);
                    }
                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(url),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(post.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              _TagChip(text: switch (post.tag) {
                PostTag.donate => 'บริจาค',
                PostTag.swap => 'แลกเปลี่ยน',
                _ => 'ประกาศ',
              }),
              const SizedBox(width: 6),

              // ✅ ปุ่มแชท (กดแล้วเปิดคุยกับเจ้าของโพสต์)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                tooltip: 'แชทกับผู้โพสต์',
                onPressed: () async {
                final myUid = FirebaseAuth.instance.currentUser?.uid;
                if (myUid == null) return;

                // กันกดแชทหาตัวเอง
                if (myUid == post.userId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('นี่คือโพสต์ของคุณเอง')),
                  );
                  return;
                }

                final kind = _kindFromTag(post.tag);

                // 1) สร้าง/เตรียมห้อง พร้อมผูกโพสต์ (1 โพสต์ต่อ 1 แชท)
               await ChatService.instance.ensureChat(
                  peerId: post.userId,
                  kind: kind,
                  postId: post.id,
                  postTitle: post.title,
                );

                // 2) ไปหน้าแชท พร้อมส่ง postId/postTitle ไปแสดงแบนเนอร์
                if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatP2PPage(
                        peerId: post.userId,
                        kind: kind,
                        postId: post.id,
                        postTitle: post.title,
                      ),
                    ),
                  );
              },


              ),
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: post.imageUrl == null || post.imageUrl!.isEmpty
                ? Container(color: const Color(0xFF1E1E1E))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(post.imageUrl!, fit: BoxFit.cover),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_ago(post.createdAt), style: TextStyle(color: hint)),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});
  final String text;

  Color _bg() {
    switch (text) {
      case 'บริจาค':
        return const Color(0xFFEAF7EE);
      case 'แลกเปลี่ยน':
        return const Color(0xFFE9F3FF);
      default:
        return const Color(0xFFFFF5E5);
    }
  }

  Color _fg() {
    switch (text) {
      case 'บริจาค':
        return const Color(0xFF2FA562);
      case 'แลกเปลี่ยน':
        return const Color(0xFF2E6EEA);
      default:
        return const Color(0xFFAD7A12);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _bg(), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: _fg(), fontSize: 11)),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.onTap, this.badge, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.black87;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color),
                if ((badge ?? 0) > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text('${badge!}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
