import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';

typedef BottomBodyBuilder = Widget Function(BuildContext context, ScrollController controller);

class AppBottomScaffold extends StatelessWidget {
  const AppBottomScaffold({
    super.key,
    required this.currentIndex,        // index ที่ active (0..4)
    required this.onTap,               // callback เวลาเปลี่ยนแท็บ
    required this.bodyBuilder,         // สร้างเนื้อหาพร้อม controller
    this.badgeChat = 0,                // แดงๆ บนไอคอนแชท
  });

  final int currentIndex;
  final void Function(int index) onTap;
  final BottomBodyBuilder bodyBuilder;
  final int badgeChat;

  @override
  Widget build(BuildContext context) {
    // ใช้ DefaultTabController แทนการโยน TabController ออกไป
    return DefaultTabController(
      initialIndex: currentIndex,
      length: 5,
      child: BottomBar(
        fit: StackFit.expand,
        barAlignment: Alignment.bottomCenter,
        width: double.infinity,
        start: 0, end: 0, offset: 0,
        showIcon: false,
        hideOnScroll: true,
        scrollOpposite: false,
        duration: const Duration(milliseconds: 420),
        curve: Curves.decelerate,
        barDecoration: const BoxDecoration(
          color: Color.fromARGB(255, 165, 206, 240), // 💙 ฟ้าอ่อน
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Builder(
          builder: (context) {
            final tab = DefaultTabController.of(context);
            return TabBar(
              controller: tab,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              dividerColor: Colors.transparent,
              indicatorPadding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color.fromARGB(255, 86, 155, 247), width: 3),
                insets: EdgeInsets.fromLTRB(16, 0, 16, 8),
              ),
              onTap: (i) {
                // ให้ผู้ใช้ตัดสินใจว่าจะนำทางยังไง
                onTap(i);
                // ทำให้แท็บเด้งกลับมาที่ currentIndex ถ้าไม่อยากค้างแท็บอื่น
                tab.animateTo(currentIndex);
              },
              tabs: [
                const _NavIcon(Icons.home),
                const _NavIcon(Icons.leaderboard),
                const _NavIcon(Icons.add),
                _ChatIcon(badge: badgeChat),
                const _NavIcon(Icons.person),
              ],
            );
          },
        ),
        body: (context, controller) => SafeArea(bottom: false, child: bodyBuilder(context, controller)),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 55, width: 40, child: Center(child: Icon(icon, color: Colors.white)));
  }
}

class _ChatIcon extends StatelessWidget {
  const _ChatIcon({this.badge = 0});
  final int badge;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55, width: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(child: Icon(Icons.chat_bubble_rounded, color: Colors.white)),
          if (badge > 0)
            Positioned(
              right: -6, top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10))),
              ),
            ),
        ],
      ),
    );
  }
}
