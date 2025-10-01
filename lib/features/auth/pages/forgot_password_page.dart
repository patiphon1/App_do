import 'package:flutter/material.dart';
import '../../../services/otp_service.dart';
import 'verify_code_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController(text: '');
  final formKey = GlobalKey<FormState>();
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.6);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
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
                    // Title
                    const Text(
                      'Reset password',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter email to send one time Password',
                      style: TextStyle(color: hint),
                    ),
                    const SizedBox(height: 26),

                    // Label
                    const Text('Your Email', style: TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 8),

                    // Email Field (card-like)
                    Container(
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
                      child: TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? 'Please enter a valid email' : null,
                        decoration: InputDecoration(
                          hintText: 'tester@gmail.com',
                          prefixIcon: const Icon(Icons.mail_outline),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF6EA8FF), width: 2),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Continue button
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: loading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setState(() => loading = true);
                                try {
                                  // ส่ง OTP ไปอีเมล
                                  await OtpService.instance.sendOtp(email.text);
                                  if (!mounted) return;
                                  // ไปหน้า Verify (กรอก 6 หลัก)
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          VerifyCodePage(email: email.text.trim()),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to send OTP: $e')),
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
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: .2,
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Continue'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Small tip
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: hint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'We’ll send a 6-digit code to your email.',
                            style: TextStyle(color: hint, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 450),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF8F9FB),
      
    );
  }
}
