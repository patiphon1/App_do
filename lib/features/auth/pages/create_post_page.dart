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

  List<String> _keywords(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9ก-๙\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _pickFrom(ImageSource src) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: src, imageQuality: 85, maxWidth: 1920);
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () async { Navigator.pop(context); await _pickFrom(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('ถ่ายรูป'),
              onTap: () async { Navigator.pop(context); await _pickFrom(ImageSource.camera); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โปรดล็อกอินก่อนโพสต์')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      String? imageUrl;
      if (_image != null) {
        imageUrl = await StorageService().uploadPostImage(_image!, user.uid);
      }

      final u = user;
      final meSnap = await FirebaseFirestore.instance.doc('users/${u.uid}').get();
      final me = meSnap.data() ?? <String, dynamic>{};

      final now = DateTime.now();
      final expiresAt = Timestamp.fromDate(now.add(const Duration(days: 7)));

      await FirebaseFirestore.instance.collection('posts').add({
        'userId'       : u.uid,
        'userName'     : u.displayName ?? (u.email ?? 'User'),
        'userAvatar'   : u.photoURL ?? '',
        'title'        : _title.text.trim(),
        'imageUrl'     : imageUrl,
        'tag'          : _tag,
        'comments'     : 0,
        'expiresAt'    : expiresAt,
        'createdAt'    : FieldValue.serverTimestamp(),
        'titleKeywords': _keywords(_title.text),
        'ownerDisplayName': (me['displayName'] ?? u.displayName ?? u.email ?? 'ผู้ใช้'),
        'ownerPhotoURL'   : (me['photoURL'] ?? u.photoURL ?? ''),
        'ownerVerified'   : (me['verified'] ?? false) == true,
        'ratingsTotal': 0,
        'ratingsCount': 0,
        'ratingAvg'   : 0,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('สร้างโพสต์'), centerTitle: true, elevation: 0),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('เขียนข้อความ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _title,
                      maxLines: 3,
                      maxLength: 160,
                      textInputAction: TextInputAction.newline,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'กรอกข้อความ' : null,
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ข้อความโพสต์...',
                        filled: true,
                        fillColor: cs.surface,
                        contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.primary, width: 1.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'เคล็ดลับ: ใช้คำสำคัญในข้อความเพื่อค้นหาเจอง่ายขึ้น',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('หมวดหมู่', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _TagChip(label: 'ประกาศ', selected: _tag == 'announce', onTap: () => setState(() => _tag = 'announce'), bg: const Color(0xFFFFF5E5), fg: const Color(0xFFAD7A12)),
                        _TagChip(label: 'บริจาค', selected: _tag == 'donate',   onTap: () => setState(() => _tag = 'donate'),   bg: const Color(0xFFEAF7EE), fg: const Color(0xFF2FA562)),
                        _TagChip(label: 'แลกเปลี่ยน', selected: _tag == 'swap', onTap: () => setState(() => _tag = 'swap'),     bg: const Color(0xFFE9F3FF), fg: const Color(0xFF2E6EEA)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('รูปภาพ (ไม่บังคับ)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (_image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(aspectRatio: 16 / 9, child: Image.file(_image!, fit: BoxFit.cover)),
                      )
                    else
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Center(child: Icon(Icons.image_outlined, size: 42, color: cs.outline)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          label: const Text('เลือกรูป'),
                        ),
                        const SizedBox(width: 8),
                        if (_image != null)
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _image = null),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('ลบรูป'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('โพสต์'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.bg,
    required this.fg,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? fg.withOpacity(.12) : bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? fg : bg.withOpacity(.8)),
          boxShadow: isSelected
              ? [BoxShadow(color: fg.withOpacity(.15), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(color: fg, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
