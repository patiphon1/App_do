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
  bool _saving = false;
  String? _photoUrl;

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

  Future<void> _save() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขโปรไฟล์', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
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
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('บันทึก'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
