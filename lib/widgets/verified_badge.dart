import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final bool verified;
  const VerifiedBadge({super.key, required this.verified});

  @override
  Widget build(BuildContext context) {
    if (!verified) {
      return Row(children: const [
        Icon(Icons.info_outline, size: 18),
        SizedBox(width: 6),
        Text('ยังไม่ยืนยันตัวตน'),
      ]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: const [
        Icon(Icons.verified, color: Colors.green, size: 18),
        SizedBox(width: 6),
        Text('ยืนยันตัวตนแล้ว', style: TextStyle(color: Colors.green)),
      ]),
    );
    }
}
