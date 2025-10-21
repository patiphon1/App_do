import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'chat_p2p_page.dart';
import '../../services/chat_service.dart';
import '../../features/auth/pages/create_post_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> with TickerProviderStateMixin {
  // แท็บบน (บริจาค/ขอรับ/แลกเปลี่ยน)
  late final TabController _topTab = TabController(length: 3, vsync: this);

  // เมนูล่าง (0=home,1=search/leaderboard,2=add,3=chat,4=profile)
  int _bottomIndex = 3;

  // ตัวอย่าง badge ที่ไอคอนแชท (คุณจะเปลี่ยนเป็นค่าจริงจาก backend ก็ได้)
  int _chatBadge = 2;

  @override
  void initState() {
    super.initState();
    // ให้เปิดที่ "ขอรับ" เพราะส่วนใหญ่มักมีเธรดอยู่ที่ kind: 'request'
    _topTab.index = 1;
  }

  @override
  void dispose() {
    _topTab.dispose();
    super.dispose();
  }

  Future<void> _handleBottomTap(int i) async {
    if (i == _bottomIndex) return;

    // ปุ่มกลาง: เปิดหน้าสร้างโพสต์ แล้วคง index เดิมไว้ (หน้าแชท)
    if (i == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreatePostPage()),
      );
      return;
    }

    // อัปเดตอินเด็กซ์เพื่อให้ไฮไลต์ถูกต้อง
    setState(() => _bottomIndex = i);

    // นำทางไป route หลัก (ใช้ pushReplacementNamed เพื่อไม่ซ้อนสแตกหน้าเดิม)
    switch (i) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/leaderboard'); // หรือ '/search'
        break;
      case 3:
        // อยู่หน้า Chat อยู่แล้ว (ถ้าเรียกจากหน้าอื่น ให้ใช้ route '/chat')
        // Navigator.pushReplacementNamed(context, '/chat');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ---------- AppBar + แท็บหมวดแชท ----------
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
        title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Column(
            children: [
              TabBar(
                controller: _topTab,
                labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'บริจาค'),
                  Tab(text: 'ขอรับ'),
                  Tab(text: 'แลกเปลี่ยน'),
                ],
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      ),

      // ---------- เนื้อหาแชท ----------
      body: TabBarView(
        controller: _topTab,
        children: const [
          _ChatList(kind: 'donate'),
          _ChatList(kind: 'request'),
          _ChatList(kind: 'swap'),
        ],
      ),

      // ---------- เมนูล่างแบบโค้ง (ฟ้าอ่อน) ----------
      bottomNavigationBar: CurvedNavigationBar(
        items: [
          const Icon(Icons.home, color: Colors.white),
          const Icon(Icons.leaderboard, color: Colors.white),
          const Icon(Icons.add, color: Colors.white),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(child: Icon(Icons.chat_bubble_rounded, color: Colors.white)),
              if (_chatBadge > 0)
                Positioned(
                  right: -6, top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(child: Text('$_chatBadge', style: const TextStyle(color: Colors.white, fontSize: 10))),
                  ),
                ),
            ],
          ),
          const Icon(Icons.person, color: Colors.white),
        ],
        index: _bottomIndex,
        height: 60,
        color: const Color.fromARGB(255, 165, 206, 240),       // 💙 สีบาร์ฟ้าอ่อน
        buttonBackgroundColor: const Color.fromARGB(255, 86, 155, 247), // ปุ่มกลม
        backgroundColor: Colors.transparent,
        onTap: _handleBottomTap,
      ),
    );
  }
}

// ... import เดิมคงไว้

class _ChatList extends StatelessWidget {
  const _ChatList({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final myUid = user?.uid;

    // ถ้าไม่ล็อกอิน: ไม่เปิด stream และไม่ใช้ operator !
    if (myUid == null) {
      return _CenteredNote(
        title: 'ยังไม่ได้ล็อกอิน',
        subtitle: 'เข้าสู่ระบบเพื่อดูแชทของคุณ',
        actionText: 'ไปหน้า Home',
        onAction: () => Navigator.pushReplacementNamed(context, '/home'),
      );
    }

    final svc = ChatService.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: svc.myThreads(kind: kind),
      builder: (context, snap) {
        if (snap.hasError) {
          final err = snap.error.toString();
          final isIndex = err.contains('FAILED_PRECONDITION') || err.contains('requires an index');
          final isDenied = err.contains('PERMISSION_DENIED') || err.contains('permission-denied');
          return _CenteredNote(
            title: 'โหลดรายการแชทไม่สำเร็จ',
            subtitle: isIndex
                ? 'ต้องสร้าง Composite Index: users(array-contains) + kind(ASC) + lastAt(DESC)'
                : (isDenied ? 'สิทธิ์ไม่พอ: ตรวจสอบ Rules ให้ตรงกับ query' : err),
            actionText: 'ตกลง',
          );
        }

        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('ยังไม่มีแชทในหมวดนี้'));
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 88),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final data = docs[i].data();

            final lastText = (data['lastText'] ?? '') as String;
            final ts = (data['lastAt'] as Timestamp?)?.toDate();
            final timeLabel = _fmtTime(ts);

            final postId = (data['postId'] as String?) ?? '';
            final postTitle = (data['postTitle'] as String?) ?? '';

            // หา peerId
            String peerId = '';
            final peerMap = data['peerMap'] as Map<String, dynamic>?;
            if (peerMap != null && peerMap[myUid] is String) {
              peerId = peerMap[myUid] as String;
            } else {
              final users = (data['users'] as List?)?.cast<String>() ?? const <String>[];
              peerId = users.firstWhere((u) => u != myUid, orElse: () => '');
            }
            if (peerId.isEmpty) return const SizedBox.shrink();

            // unread ต้องป้องกัน null key
            final unreadMap = (data['unread'] as Map<String, dynamic>?) ?? const {};
            final unread = (myUid != null) ? (unreadMap[myUid] ?? 0) as int : 0;

            return ListTile(
              leading: const CircleAvatar(),
              title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').doc(peerId).snapshots(),
                builder: (context, snapUser) {
                  if (!snapUser.hasData) return const Text('กำลังโหลด...');
                  final u = snapUser.data!.data();
                  var name = (u?['displayName'] as String?)?.trim();
                  name = (name == null || name.isEmpty) ? peerId : name;

                  final titleText = postTitle.isNotEmpty ? '$name ($postTitle)' : name!;
                  return Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  );
                },
              ),
              subtitle: Text(
                (lastText.trim().isNotEmpty) ? lastText : 'เริ่มต้นการสนทนา',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  if (unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                ],
              ),
              onTap: () async {
                await svc.clearUnread(peerId, postId: postId);
                if (!context.mounted) return;
                final chatId = docs[i].id;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatP2PPage(
                      peerId: peerId,
                      kind: kind,
                      postId: postId,
                      postTitle: postTitle,
                      chatId: chatId,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}


class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.title, this.subtitle, this.actionText, this.onAction});
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (actionText != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction ?? () {}, child: Text(actionText!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _fmtTime(DateTime? dt) {
  if (dt == null) return '—';
  final now = DateTime.now();
  final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (isToday) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
}
