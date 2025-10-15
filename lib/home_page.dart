import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/curved_nav_scaffold.dart';
import '../../features/auth/pages/profile_view_page.dart';
import '../../features/auth/pages/create_post_page.dart';
import '../../services/chat_service.dart';
import '../features/chat/chat_p2p_page.dart';

enum PostTag { announce, donate, swap }
PostTag _tagFrom(String? s) =>
    switch (s) { 'donate' => PostTag.donate, 'swap' => PostTag.swap, _ => PostTag.announce };
String _tagTo(PostTag t) =>
    switch (t) { PostTag.donate => 'donate', PostTag.swap => 'swap', PostTag.announce => 'announce' };
String _kindFromTag(PostTag t) =>
    switch (t) { PostTag.donate => 'donate', PostTag.swap => 'swap', PostTag.announce => 'request' };

class Post {
  final String id, userId, userName, userAvatar, title;
  final String? imageUrl;
  final PostTag tag;
  final int comments;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.userId,
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
      userId: (d['userId'] ?? '').toString(),
      userName: (d['userName'] ?? '').toString(),
      userAvatar: (d['userAvatar'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      imageUrl: d['imageUrl'] as String?,
      tag: _tagFrom(d['tag']),
      comments: (d['comments'] ?? 0) as int,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _col = FirebaseFirestore.instance.collection('posts');
  final _search = TextEditingController();
  List<Post> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false, _loadingMore = false;
  int _chatBadge = 2;
  PostTag? _selectedTag;
  int _activeFilters = 0;

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> q =
          _col.orderBy('createdAt', descending: true).limit(50);
      if (_selectedTag != null) {
        q = q.where('tag', isEqualTo: _tagTo(_selectedTag!));
      }
      final snap = await q.get();
      final now = DateTime.now();
      var all = snap.docs.map(Post.fromDoc).toList();

      // keep only not-expired
      all = all.where((p) {
        final doc = snap.docs.firstWhere((d) => d.id == p.id);
        final expiresAt = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
        return expiresAt == null || expiresAt.isAfter(now);
      }).toList();

      // keyword filter (client side)
      final s = _search.text.trim().toLowerCase();
      if (s.isNotEmpty) {
        all = all.where((p) => p.title.toLowerCase().contains(s)).toList();
      }

      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _items = all;
        _cursor = snap.docs.isNotEmpty ? snap.docs.last : null;
      });
    } catch (e) {
      debugPrint('loadFirst error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      Query<Map<String, dynamic>> q =
          _col.orderBy('createdAt', descending: true).startAfterDocument(_cursor!).limit(10);
      if (_selectedTag != null) {
        q = q.where('tag', isEqualTo: _tagTo(_selectedTag!));
      }
      final snap = await q.get();
      final now = DateTime.now();
      var more = snap.docs.map(Post.fromDoc).toList();

      more = more.where((p) {
        final doc = snap.docs.firstWhere((d) => d.id == p.id);
        final expiresAt = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
        return expiresAt == null || expiresAt.isAfter(now);
      }).toList();

      more.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _items.addAll(more);
        _cursor = snap.docs.isNotEmpty ? snap.docs.last : null;
      });
    } catch (e) {
      debugPrint('loadMore error: $e');
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

  Future<void> _onBottomTap(int i) async {
    switch (i) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/leaderboard');
        break;
      case 2:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage()));
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/chat');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CurvedNavScaffold(
      currentIndex: 0,
      chatBadge: _chatBadge,
      onTap: _onBottomTap,
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                // เคลียร์ทุกหน้าก่อนหน้า แล้วไปหน้า login
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ออกจากระบบไม่สำเร็จ: $e')),
                );
              }
            },
          ),
        ],
      ),
      bodyBuilder: (context) {
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (!_loadingMore &&
                    _cursor != null &&
                    n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                  _loadMore();
                }
                return false;
              },
              child: CustomScrollView(
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
                                suffixIcon: (_search.text.isEmpty)
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () {
                                          _search.clear();
                                          _loadFirst();
                                        },
                                      ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                                filled: true,
                                fillColor: const Color(0xFFF5F6F7),
                              ),
                              onChanged: (_) => setState(() {}),
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
      },
    );
  }
}

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
          _chip('All', _sel == null, () => setState(() => _sel = null)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              _chip('ประกาศ', _sel == PostTag.announce, () => setState(() => _sel = PostTag.announce)),
              _chip('บริจาค', _sel == PostTag.donate, () => setState(() => _sel = PostTag.donate)),
              _chip('แลกเปลี่ยน', _sel == PostTag.swap, () => setState(() => _sel = PostTag.swap)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _sel),
              child: const Text('Apply filter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    return ChoiceChip(label: Text(text), selected: selected, onSelected: (_) => onTap());
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
            right: -2, top: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              child: Center(
                child: Text('${badge!}', style: const TextStyle(color: Colors.white, fontSize: 12)),
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
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('publicUsers').doc(post.userId).snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final name = (data?['displayName'] ?? post.userName).toString();
                  final photoURL = (data?['photoURL'] ?? post.userAvatar) as String?;
                  final verified = (data?['verified'] ?? false) == true;

                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileViewPage(viewUid: post.userId)),
                    ),
                    borderRadius: BorderRadius.circular(999),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: (photoURL != null && photoURL.isNotEmpty) ? NetworkImage(photoURL) : null,
                          child: (photoURL == null || photoURL.isEmpty) ? const Icon(Icons.person) : null,
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, size: 16, color: Color(0xFF2ECC71)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
              _TagChip(text: switch (post.tag) {
                PostTag.donate => 'บริจาค',
                PostTag.swap => 'แลกเปลี่ยน',
                _ => 'ประกาศ',
              }),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                tooltip: 'แชทกับผู้โพสต์',
                onPressed: () async {
                  final myUid = FirebaseAuth.instance.currentUser?.uid;
                  if (myUid == null) return;
                  if (myUid == post.userId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('นี่คือโพสต์ของคุณเอง')),
                    );
                    return;
                  }
                  final kind = _kindFromTag(post.tag);
                  await ChatService.instance.ensureChat(
                    peerId: post.userId,
                    kind: kind,
                    postId: post.id,
                    postTitle: post.title,
                  );
                  final chatId = ChatService.instance.chatIdOf(myUid, post.userId, postId: post.id);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatP2PPage(
                        peerId: post.userId,
                        kind: kind,
                        postId: post.id,
                        postTitle: post.title,
                        chatId: chatId,
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              post.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
      case 'บริจาค': return const Color(0xFFEAF7EE);
      case 'แลกเปลี่ยน': return const Color(0xFFE9F3FF);
      default: return const Color(0xFFFFF5E5);
    }
  }
  Color _fg() {
    switch (text) {
      case 'บริจาค': return const Color(0xFF2FA562);
      case 'แลกเปลี่ยน': return const Color(0xFF2E6EEA);
      default: return const Color(0xFFAD7A12);
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
