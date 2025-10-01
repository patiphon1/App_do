import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/otp_service.dart';
import 'reset_password_page.dart';

class VerifyCodePage extends StatefulWidget {
  final String email;
  const VerifyCodePage({super.key, required this.email});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  bool loading = false;

  String get code => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  // เคลื่อนโฟกัสไปช่องถัดไป/ก่อนหน้า + รองรับ paste 6 หลัก
  void _onChanged(int i, String value) {
    final v = value.trim();
    if (v.length > 1) {
      final onlyDigits = v.replaceAll(RegExp(r'\D'), '');
      for (var k = 0; k < 6; k++) {
        _controllers[k].text = k < onlyDigits.length ? onlyDigits[k] : '';
      }
      final last = (onlyDigits.length.clamp(1, 6)) - 1;
      _nodes[last].requestFocus();
      setState(() {});
      return;
    }
    if (v.isNotEmpty && i < 5) {
      _nodes[i + 1].requestFocus();
    } else if (v.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
    }
    setState(() {});
  }

  // กด backspace ตอนช่องว่าง → ย้อนโฟกัส
  KeyEventResult _onKey(int i, KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[i].text.isEmpty &&
        i > 0) {
      _nodes[i - 1].requestFocus();
      _controllers[i - 1].selection =
          TextSelection.collapsed(offset: _controllers[i - 1].text.length);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _submit() async {
    if (code.length != 6 || code.contains(RegExp(r'\D'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter 6-digit code')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final token = await OtpService.instance.verifyOtp(widget.email, code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(email: widget.email, token: token),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verify failed: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.6);

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Verification Code",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "We have sent the verification code to your email address",
              style: TextStyle(color: hint),
            ),
            const SizedBox(height: 22),

            const Text("Your Email"),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: widget.email,
              readOnly: true,
            ),

            const SizedBox(height: 20),

            // กล่อง OTP 6 ช่อง (สไตล์ตามตัวอย่าง)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return _OtpBox(
                  controller: _controllers[i],
                  node: _nodes[i],
                  onChanged: (v) => _onChanged(i, v),
                  onKey: (e) => _onKey(i, e),
                  onSubmitted: i == 5 ? (_) => _submit() : null,
                );
              }),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6EA8FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- OTP Box Widget ---------------------------- */

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.node,
    required this.onChanged,
    required this.onKey,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode node;
  final void Function(String) onChanged;
  final KeyEventResult Function(KeyEvent) onKey;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Focus(
        focusNode: node,
        onKeyEvent: (_, e) => onKey(e),
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          enableSuggestions: false,
          autocorrect: false,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          maxLength: 1,
          buildCounter: (context,
                  {required int currentLength,
                  required bool isFocused,
                  required int? maxLength}) =>
              null,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF6EA8FF), width: 2),
            ),
          ),
          inputFormatters:  [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}
