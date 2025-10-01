import 'package:flutter/material.dart';
import '../../../services/otp_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String token;
  const ResetPasswordPage({super.key, required this.email, required this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final pass = TextEditingController();
  final confirm = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscure1 = true;
  bool obscure2 = true;
  bool loading = false;

  @override
  void dispose() {
    pass.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.6);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Form(
                key: formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text(
                      'Create a New Password',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use 6+ characters with letters and numbers',
                      style: TextStyle(color: hint),
                    ),
                    const SizedBox(height: 24),

                    const Text('New Password', style: TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 8),
                    _CardField(
                      child: TextFormField(
                        controller: pass,
                        obscureText: obscure1,
                        validator: (v) =>
                            (v == null || v.length < 6) ? 'Min 6 characters' : null,
                        decoration: InputDecoration(
                          hintText: '••••••••••',
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                          suffixIcon: IconButton(
                            icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscure1 = !obscure1),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text('Confirm-Password', style: TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 8),
                    _CardField(
                      child: TextFormField(
                        controller: confirm,
                        obscureText: obscure2,
                        validator: (v) => (v != pass.text) ? 'Passwords do not match' : null,
                        decoration: InputDecoration(
                          hintText: '••••••••••',
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                          suffixIcon: IconButton(
                            icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscure2 = !obscure2),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: loading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setState(() => loading = true);
                                try {
                                  await OtpService.instance.resetPassword(
                                    widget.email,
                                    widget.token,
                                    pass.text,
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Password reset successful!'),
                                    ),
                                  );
                                  Navigator.popUntil(context, (r) => r.isFirst);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Reset failed: $e')),
                                  );
                                } finally {
                                  if (mounted) setState(() => loading = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6EA8FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .2),
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,
                                ),
                              )
                            : const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// กล่องการ์ดโค้งมน + เงาอ่อน ใช้หุ้ม TextFormField
class _CardField extends StatelessWidget {
  const _CardField({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
