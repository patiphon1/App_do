import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/verification_service.dart';

class VerifySubmitPage extends StatefulWidget {
  const VerifySubmitPage({super.key});
  @override
  State<VerifySubmitPage> createState() => _VerifySubmitPageState();
}

class _VerifySubmitPageState extends State<VerifySubmitPage> {
  final _picker = ImagePicker();
  XFile? _front;
  XFile? _back;
  bool _loading = false;

  Future<void> _pick(bool isFront) async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => isFront ? _front = x : _back = x);
  }

  Future<void> _submit() async {
    if (_front == null || _back == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกรูปทั้งด้านหน้าและด้านหลัง')));
      return;
    }
    setState(() => _loading = true);
    try {
      await VerificationService().submit(_front!, _back!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ส่งคำขอแล้ว กำลังตรวจสอบ')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันตัวตน')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _pick(true),
                child: AspectRatio(
                  aspectRatio: 16/10,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                      image: _front != null
                        ? DecorationImage(image: FileImage(Uri.parse(_front!.path).toFilePath() as dynamic), fit: BoxFit.cover)
                        : null,
                    ),
                    child: _front == null ? const Center(child: Text('เลือกรูปบัตรด้านหน้า')) : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _pick(false),
                child: AspectRatio(
                  aspectRatio: 16/10,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                      image: _back != null
                        ? DecorationImage(image: FileImage(Uri.parse(_back!.path).toFilePath() as dynamic), fit: BoxFit.cover)
                        : null,
                    ),
                    child: _back == null ? const Center(child: Text('เลือกรูปบัตรด้านหลัง')) : null,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const Text('อัปโหลดรูปบัตรประชาชนด้านหน้าและด้านหลังเพื่อยืนยันตัวตน'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: const Text('ส่งคำขอ'),
            ),
          ),
        ]),
      ),
    );
  }
}
