import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminUserManagerPage extends StatefulWidget {
  const AdminUserManagerPage({super.key});

  @override
  State<AdminUserManagerPage> createState() => _AdminUserManagerPageState();
}

class _AdminUserManagerPageState extends State<AdminUserManagerPage> {
  final _qCtl = TextEditingController();
  bool _busy = false;

  DocumentSnapshot<Map<String, dynamic>>? _result;

  Future<void> _search() async {
    final q = _qCtl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _result = null;
    });

    try {
      final fs = FirebaseFirestore.instance;
      DocumentSnapshot<Map<String, dynamic>>? userDoc;

      // ถ้าดูเหมือน uid (ยาวๆ) ลองอ่านตรงๆก่อน
      if (q.length >= 20) {
        final snap = await fs.doc('users/$q').get();
        if (snap.exists) userDoc = snap;
      }

      // ไม่เจอ → หาด้วยอีเมล
      if (userDoc == null) {
        final qs = await fs
            .collection('users')
            .where('email', isEqualTo: q)
            .limit(1)
            .get();
        if (qs.docs.isNotEmpty) userDoc = qs.docs.first;
      }

      if (userDoc == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ไม่พบผู้ใช้')));
      }

      setState(() => _result = userDoc);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setRole(String uid, String role) async {
    try {
      setState(() => _busy = true);
      // เรียก Cloud Function (ต้องมี functions:setUserRole ตามที่ให้ไปก่อนหน้า)
      await FirebaseFunctions.instance
          .httpsCallable('setUserRole')
          .call({'uid': uid, 'role': role});

      // refresh
      final snap =
          await FirebaseFirestore.instance.doc('users/$uid').get();
      setState(() => _result = snap);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(role == 'admin'
              ? 'ตั้งเป็นแอดมินแล้ว'
              : 'ปลดแอดมินแล้ว')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _qCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการสิทธิ์ผู้ใช้')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: (meUid == null)
            ? const Stream.empty()
            : FirebaseFirestore.instance.doc('users/$meUid').snapshots(),
        builder: (context, meSnap) {
          final meRole = meSnap.data?.data()?['role'];
          if (meRole != 'admin') {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'ต้องเป็นแอดมินเท่านั้นถึงจะเข้าหน้านี้ได้',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            );
          }

          final u = _result?.data();
          final uid = _result?.id;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _qCtl,
                      decoration: const InputDecoration(
                        labelText: 'ค้นหาด้วย Email หรือ UID',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _search,
                    child: Text(_busy ? '...' : 'ค้นหา'),
                  ),
                ]),
                const SizedBox(height: 16),

                if (u != null && uid != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('UID: $uid',
                              style:
                                  const TextStyle(fontFamily: 'monospace')),
                          const SizedBox(height: 6),
                          Text('ชื่อ: ${u['displayName'] ?? '-'}'),
                          Text('อีเมล: ${u['email'] ?? '-'}'),
                          Text('เบอร์: ${u['phone'] ?? '-'}'),
                          Text('role: ${u['role'] ?? 'user'}'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _busy ||
                                        (u['role']?.toString() == 'admin')
                                    ? null
                                    : () => _setRole(uid, 'admin'),
                                icon: const Icon(Icons.arrow_upward),
                                label: const Text('ตั้งเป็นแอดมิน'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _busy ||
                                        (u['role']?.toString() == 'user' ||
                                            u['role'] == null)
                                    ? null
                                    : () => _setRole(uid, 'user'),
                                icon: const Icon(Icons.arrow_downward),
                                label: const Text('ปลดแอดมิน'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
