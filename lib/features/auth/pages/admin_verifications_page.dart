import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminVerificationsPage extends StatefulWidget {
  const AdminVerificationsPage({super.key});

  @override
  State<AdminVerificationsPage> createState() => _AdminVerificationsPageState();
}

class _AdminVerificationsPageState extends State<AdminVerificationsPage> {
  bool _busy = false;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  Future<void> _approve(BuildContext context, String uid) async {
    try {
      setState(() => _busy = true);
      await _functions
          .httpsCallable('reviewVerification')
          .call({'uid': uid, 'action': 'approve'});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('อนุมัติแล้ว')));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${e.code}: ${e.message ?? ''}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(BuildContext context, String uid) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('เหตุผลการปฏิเสธ'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'ระบุเหตุผล...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (reason == null) return;

    try {
      setState(() => _busy = true);
      await _functions
          .httpsCallable('reviewVerification')
          .call({'uid': uid, 'action': 'reject', 'reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ปฏิเสธแล้ว')));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${e.code}: ${e.message ?? ''}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('verifications')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('คำขอยืนยันตัวตน (รอตรวจ)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('โหลดไม่สำเร็จ: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('ไม่มีคำขอใหม่'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final m = doc.data();
              final uid = doc.id; // ใช้ doc.id เป็น uid
              final createdAt = (m['createdAt'] as Timestamp?)?.toDate();
              return ListTile(
                title: Text(uid, style: const TextStyle(fontFamily: 'monospace')),
                subtitle: Text(createdAt != null
                    ? 'สร้างเมื่อ: ${createdAt.toLocal()}'
                    : 'สร้างเมื่อ: -'),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _VerificationDetail(uid: uid, data: m),
                  ));
                },
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => _reject(context, uid),
                      child: const Text('ปฏิเสธ'),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : () => _approve(context, uid),
                      child: const Text('อนุมัติ'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _VerificationDetail extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _VerificationDetail({required this.uid, required this.data});

  @override
  Widget build(BuildContext context) {
    final front = data['frontUrl'] as String?;
    final back = data['backUrl'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text('ตรวจสอบ: $uid')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('บัตรด้านหน้า', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _netImage(front),
          const SizedBox(height: 16),
          const Text('บัตรด้านหลัง', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _netImage(back),
        ],
      ),
    );
  }

  Widget _netImage(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        color: Colors.black12,
        child: const Text('ไม่มีรูป'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (c, w, p) => p == null
              ? w
              : SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(value: p.expectedTotalBytes != null
                        ? (p.cumulativeBytesLoaded / (p.expectedTotalBytes!))
                        : null),
                  ),
                ),
          errorBuilder: (c, e, s) => Container(
            height: 180,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Text('โหลดรูปไม่สำเร็จ'),
          ),
        ),
      ),
    );
  }
}
