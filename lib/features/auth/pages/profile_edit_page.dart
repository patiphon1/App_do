// lib/features/profile/pages/profile_edit_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _phone;

  bool _saving = false;           // บันทึกโปรไฟล์
  bool _verSubmitting = false;    // ส่งคำขอยืนยัน
  String? _photoUrl;

  // รูปบัตรที่จะอัปโหลด
  XFile? _front;
  XFile? _back;

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _bio = TextEditingController();
    _phone = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final doc = await _fire.collection('users').doc(_uid).get();
    final u = doc.data() ?? {};
    setState(() {
      _name.text = u['displayName'] ?? _auth.currentUser?.displayName ?? '';
      _bio.text = u['bio'] ?? '';
      _phone.text = u['phone'] ?? '';
      _photoUrl = u['photoUrl'] ?? _auth.currentUser?.photoURL;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    setState(() => _saving = true);
    try {
      final ref = FirebaseStorage.instance.ref('users/$_uid/avatar.jpg');
      await ref.putFile(File(x.path), SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await _fire.collection('users').doc(_uid).set({'photoUrl': url}, SetOptions(merge: true));
      setState(() => _photoUrl = url);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _fire.collection('users').doc(_uid).set({
        'displayName': _name.text.trim(),
        'bio': _bio.text.trim(),
        'phone': _phone.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (_name.text.trim().isNotEmpty) {
        await _auth.currentUser?.updateDisplayName(_name.text.trim());
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickFront() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => _front = x);
  }

  Future<void> _pickBack() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => _back = x);
  }

  // อัปโหลดไฟล์ + สร้าง/แทนที่เอกสารคำขอยืนยันของผู้ใช้
  Future<void> _submitVerification() async {
    if (_front == null || _back == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรูปบัตรประชาชนด้านหน้าและด้านหลัง')),
      );
      return;
    }
    setState(() => _verSubmitting = true);
    try {
      final st = FirebaseStorage.instance;
      final frontRef = st.ref('id-verifications/$_uid/front.jpg');
      final backRef  = st.ref('id-verifications/$_uid/back.jpg');

      await frontRef.putFile(File(_front!.path), SettableMetadata(contentType: 'image/jpeg'));
      await backRef.putFile(File(_back!.path),  SettableMetadata(contentType: 'image/jpeg'));

      final frontUrl = await frontRef.getDownloadURL();
      final backUrl  = await backRef.getDownloadURL();

      final verRef = _fire.collection('verifications').doc(_uid);
      await verRef.set({
        'uid': _uid,
        'frontUrl': frontUrl,
        'backUrl': backUrl,
        'status': 'pending',
        'reason': null,
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
      }, SetOptions(merge: true));

      await _fire.collection('auditLogs').add({
        'uid': _uid,
        'action': 'submit',
        'by': _uid,
        'at': FieldValue.serverTimestamp(),
        'note': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งคำขอยืนยันแล้ว กำลังตรวจสอบ')),
        );
        // เคลียร์รูปที่เลือก
        setState(() { _front = null; _back = null; });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _verSubmitting = false);
    }
  }

  Widget _buildVerifySection() {
    // อ่านสถานะ verifications/{uid} แบบเรียลไทม์
    final stream = _fire.collection('verifications').doc(_uid).snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final v = snap.data?.data() ?? {};
        final status = (v['status'] ?? 'none') as String; // none | pending | approved | rejected
        final reason = (v['reason'] ?? '') as String?;

        Color chipBg;
        Color chipFg;
        String chipText;
        switch (status) {
          case 'approved':
            chipBg = Colors.green.withOpacity(.12);
            chipFg = Colors.green.shade800;
            chipText = 'ยืนยันตัวตนแล้ว';
            break;
          case 'pending':
            chipBg = Colors.orange.withOpacity(.12);
            chipFg = Colors.orange.shade800;
            chipText = 'กำลังตรวจสอบ';
            break;
          case 'rejected':
            chipBg = Colors.red.withOpacity(.12);
            chipFg = Colors.red.shade800;
            chipText = 'ถูกปฏิเสธ';
            break;
          default:
            chipBg = Colors.grey.withOpacity(.12);
            chipFg = Colors.grey.shade800;
            chipText = 'ยังไม่ยืนยัน';
        }

        final disabled = status == 'pending' || status == 'approved' || _verSubmitting;

        return Card(
          margin: const EdgeInsets.only(top: 24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user, size: 20),
                    const SizedBox(width: 8),
                    const Text('ยืนยันตัวตน', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
                      child: Text(chipText, style: TextStyle(color: chipFg, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  status == 'approved'
                      ? 'บัญชีนี้ผ่านการตรวจสอบแล้ว'
                      : 'อัปโหลดรูปบัตรประชาชนด้านหน้าและด้านหลังเพื่อยืนยันตัวตน',
                  style: const TextStyle(color: Colors.black87),
                ),
                if (status == 'rejected' && (reason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('เหตุผลที่ถูกปฏิเสธ: $reason', style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),

                // ตัวเลือกภาพหน้า-หลัง
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: disabled ? null : _pickFront,
                        child: AspectRatio(
                          aspectRatio: 16/10,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _front == null
                                ? const Center(child: Text('เลือกรูปด้านหน้า'))
                                : Image.file(File(_front!.path), fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: disabled ? null : _pickBack,
                        child: AspectRatio(
                          aspectRatio: 16/10,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _back == null
                                ? const Center(child: Text('เลือกรูปด้านหลัง'))
                                : Image.file(File(_back!.path), fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: disabled ? null : _submitVerification,
                    icon: _verSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(
                      status == 'rejected' ? 'ส่งใหม่'
                      : status == 'pending' ? 'กำลังตรวจสอบ'
                      : status == 'approved' ? 'ยืนยันแล้ว'
                      : 'ส่งคำขอยืนยัน',
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                const Text(
                  'ข้อแนะนำ: เบลอข้อมูลที่ไม่จำเป็น เช่น แสดงเลขบัตรบางส่วนเท่านั้น และอัปโหลดรูปที่ชัดเจน',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขโปรไฟล์', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: const Text('เสร็จสิ้น'),
          )
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                        ? NetworkImage(_photoUrl!)
                        : null,
                    child: (_photoUrl == null || _photoUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'ชื่อที่แสดง'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'กรอกชื่อที่แสดง' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bio,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'แนะนำตัว (Bio)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('บันทึก'),
                ),

                // ===== ส่วนยืนยันตัวตน =====
                _buildVerifySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
