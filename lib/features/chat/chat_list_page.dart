import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_p2p_page.dart';
import '../../services/chat_service.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> with TickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: (){}, icon: const Icon(Icons.notifications_none_rounded)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Column(
            children: [
              TabBar(
                controller: _tab,
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
      body: TabBarView(
        controller: _tab,
        children: const [
          _ChatList(kind: 'donate'),
          _ChatList(kind: 'request'),
          _ChatList(kind: 'swap'),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _Nav(icon: Icons.home_rounded, onTap: () {/* TODO: ไปหน้า Home */}),
              _Nav(icon: Icons.notifications_rounded, badge: 1, onTap: () {/* TODO: ไปหน้าแจ้งเตือน */}),
              const Spacer(),
              _Nav(icon: Icons.chat_bubble_rounded, active: true, onTap: () {/* อยู่หน้า Chat แล้ว */}),
              _Nav(icon: Icons.person_rounded, onTap: () {/* TODO: ไปหน้าโปรไฟล์ */}),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){},
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final svc = ChatService.instance;
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: svc.myThreads(kind: kind),
      builder: (context, snap) {
        // 👉 ช่วยบอกสาเหตุจริง (เช่น index ยังไม่สร้าง / rules ผิด)
        if (snap.hasError) {
          final err = snap.error.toString();
          final isIndex = err.contains('FAILED_PRECONDITION') || err.contains('requires an index');
          return _CenteredNote(
            title: 'โหลดรายการแชทไม่สำเร็จ',
            subtitle: isIndex
                ? 'คิวรีต้องการ Composite Index: users(array-contains) + kind(ASC) + lastAt(DESC)'
                : err,
            actionText: isIndex ? 'ตกลง' : null,
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
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
            final unread = (data['unread']?[myUid] ?? 0) as int;
            final ts = (data['lastAt'] as Timestamp?)?.toDate();
            final timeLabel = _fmtTime(ts);

            // หา peerId จาก peerMap หรือ users
            String peerId = '';
            final peerMap = data['peerMap'] as Map<String, dynamic>?;
            if (peerMap != null && peerMap[myUid] is String) {
              peerId = peerMap[myUid] as String;
            } else {
              final users = (data['users'] as List?)?.cast<String>() ?? const <String>[];
              peerId = users.firstWhere((u) => u != myUid, orElse: () => '');
            }

            // กันเอกสารผิดรูป
            if (peerId.isEmpty) {
              return const SizedBox.shrink();
            }

            // ชื่อที่แสดง (ถ้าคุณเก็บที่ users/{uid} ก็สามารถดึงมาแทนได้)
            final displayName = (data['peerName'] as String?) ?? peerId;

            return ListTile(
              leading: const CircleAvatar(radius: 22),
              title: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                lastText.isEmpty ? 'เริ่มต้นการสนทนา' : lastText,
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
                await svc.clearUnread(peerId); // จะ merge แค่ unread ของตัวเอง
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatP2PPage(
                      peerName: displayName,
                      peerId: peerId,
                      kind: kind,
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
}

class _Nav extends StatelessWidget {
  const _Nav({required this.icon, this.active = false, this.badge, this.onTap});
  final IconData icon;
  final bool active;
  final int? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.black87;
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            child: SizedBox(height: 56, child: Icon(icon, color: color)),
          ),
          if ((badge ?? 0) > 0)
            Positioned(
              right: MediaQuery.of(context).size.width * .18,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10))),
              ),
            ),
        ],
      ),
    );
  }
}

/// กล่องข้อความกลางจอสำหรับ error/โน้ตเล็ก ๆ
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
            ]
          ],
        ),
      ),
    );
  }
}
