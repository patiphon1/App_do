import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

typedef CurvedBodyBuilder = Widget Function(BuildContext context);

class CurvedNavScaffold extends StatefulWidget {
  const CurvedNavScaffold({
    super.key,
    required this.currentIndex,      // 0=Home, 1=Leaderboard, 2=Add, 3=Chat, 4=Profile
    required this.onTap,             // callback นำทางเมื่อแตะเมนู
    required this.bodyBuilder,       // เนื้อหาในหน้า
    this.chatBadge = 0,
    this.appBar,
    this.height = 60,
    this.backgroundColor = Colors.transparent,
    this.barColor = const Color.fromARGB(255, 165, 206, 240),   // ฟ้าอ่อน
    this.buttonColor = const Color.fromARGB(255, 86, 155, 247), // ฟ้าปุ่มกลาง
    this.animationDuration = const Duration(milliseconds: 260),
    this.animationCurve = Curves.easeOutCubic,
  });

  final int currentIndex;
  final void Function(int index) onTap;
  final CurvedBodyBuilder bodyBuilder;
  final int chatBadge;
  final PreferredSizeWidget? appBar;
  final double height;
  final Color backgroundColor;
  final Color barColor;
  final Color buttonColor;

  /// กำหนดระยะเวลาแอนิเมชันของ navbar
  final Duration animationDuration;

  /// กำหนดคีย์ฟแอนิเมชันของ navbar
  final Curve animationCurve;

  @override
  State<CurvedNavScaffold> createState() => _CurvedNavScaffoldState();
}

class _CurvedNavScaffoldState extends State<CurvedNavScaffold> {
  late int _index;
  bool _navigating = false; // กันกดรัวระหว่างกำลังหน่วงเวลา

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex;
  }

  Future<void> _handleTap(int i) async {
    if (_navigating) return;
    _navigating = true;

    // ปุ่มกลาง (Create) ให้เปิดทันที ไม่ต้องหน่วง
    if (i == 2) {
      try {
        widget.onTap(i);
      } finally {
        _navigating = false;
      }
      return;
    }

    // อัปเดต index ให้ navbar เล่นแอนิเมชันก่อน
    if (mounted) setState(() => _index = i);

    // หน่วงให้เห็นแอนิเมชันของ CurvedNavigationBar ชัด ๆ
    await Future.delayed(widget.animationDuration);

    try {
      widget.onTap(i); // ค่อยนำทางหลังแอนิเมชันจบ
    } finally {
      _navigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.appBar,
      extendBody: true,
      body: widget.bodyBuilder(context),
      bottomNavigationBar: CurvedNavigationBar(
        index: _index,
        height: widget.height,
        backgroundColor: widget.backgroundColor,
        color: widget.barColor,
        buttonBackgroundColor: widget.buttonColor,
        animationDuration: widget.animationDuration,
        animationCurve: widget.animationCurve,
        onTap: _handleTap,
        items: [
          const Icon(Icons.home, color: Colors.white),
          const Icon(Icons.leaderboard, color: Colors.white),
          const Icon(Icons.add, color: Colors.white),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(child: Icon(Icons.chat_bubble_rounded, color: Colors.white)),
              if (widget.chatBadge > 0)
                Positioned(
                  right: -6, top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text('${widget.chatBadge}',
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ),
            ],
          ),
          const Icon(Icons.person, color: Colors.white),
        ],
      ),
    );
  }
}
