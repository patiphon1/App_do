import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/storage_service.dart'; 

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _title = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _tag = 'donate'; // 'announce' | 'donate' | 'swap'
  File? _image;
  bool _loading = false;

  // เลือกรูปจากแกลเลอรี
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => _image = File(x.path));
  }

  // helper ทำคีย์เวิร์ดไว้ค้นหา
  List<String> _keywords(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9ก-๙\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // ยังไม่ล็อกอิน → เด้งไปหน้า Login (เปลี่ยน route ตามแอปคุณ)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โปรดล็อกอินก่อนโพสต์')),
      );
      // ตัวอย่าง: Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) อัปโหลดรูป (ถ้ามี)
      String? imageUrl;
      if (_image != null) {
        imageUrl = await StorageService().uploadPostImage(_image!, user.uid);
      }
      final now = DateTime.now();
      final expiresAt = Timestamp.fromDate(now.add(const Duration(days: 7)));
      // 2) สร้างเอกสารใน Firestore
      await FirebaseFirestore.instance.collection('posts').add({
        'userId'       : user.uid,                       // ✅ ตรงกับ rules
        'userName'     : user.displayName ?? (user.email ?? 'User'),
        'userAvatar'   : user.photoURL ?? '',            // ปรับตามระบบของคุณ
        'title'        : _title.text.trim(),
        'imageUrl'     : imageUrl,
        'tag'          : _tag,                           // 'announce' | 'donate' | 'swap'
        'comments'     : 0,
        'expiresAt'    : expiresAt,
        'createdAt'    : FieldValue.serverTimestamp(),   // ✅ timestamp ตาม rules
        'titleKeywords': _keywords(_title.text),         // ใช้กับ array-contains search
      });

      if (!mounted) return;
      Navigator.pop(context, true); // ส่ง true กลับไปให้ Home reload ได้ถ้าต้องการ
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างโพสต์')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('เขียนข้อความ'),
            TextFormField(
              controller: _title,
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'กรอกข้อความ' : null,
              decoration: const InputDecoration(
                hintText: 'พิมพ์ข้อความ...',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _tag,
              items: const [
                DropdownMenuItem(value: 'announce', child: Text('announce')),
                DropdownMenuItem(value: 'donate',   child: Text('donate')),
                DropdownMenuItem(value: 'swap',     child: Text('swap')),
              ],
              onChanged: (v) => setState(() => _tag = v ?? 'donate'),
              decoration: const InputDecoration(border: UnderlineInputBorder()),
            ),
            const SizedBox(height: 20),

            // ปุ่มเลือกรูป + preview
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_image!, height: 160, fit: BoxFit.cover),
              ),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('เลือกรูป'),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('โพสต์'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
