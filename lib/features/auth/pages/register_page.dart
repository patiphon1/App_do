import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart'; // Service  Auth
import '../../../data/repositories/user_repository.dart';
import '../../../data/models/app_user.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final username = TextEditingController();
  final email = TextEditingController();
  final idCard = TextEditingController();
  final phone = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscure1 = true;
  bool obscure2 = true;
  bool loading = false;

  void _show(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _doRegister() async {
  if (!formKey.currentState!.validate()) return;
  setState(() => loading = true);
  try {
    final cred = await AuthService.instance.signUp(
      email.text,
      pass.text,
      displayName: username.text.trim(),
    );

    final user = cred.user!;
    // สร้างเอกสารโปรไฟล์ (ครั้งแรกเท่านั้น)
    await UserRepository.instance.createIfNotExists(
      AppUser(
        uid: user.uid,
        email: user.email ?? email.text.trim(),
        displayName: user.displayName ?? username.text.trim(),
        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('สมัครสมาชิกสำเร็จ')),
    );
    // ไปหน้า Home (ให้ AuthGate จัดการเส้นทาง)
    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;
    final msg = (e is FirebaseException) ? e.message ?? 'เกิดข้อผิดพลาด' : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } finally {
    if (mounted) setState(() => loading = false);
  }
}

  @override
  void dispose() {
    username.dispose();
    email.dispose();
    idCard.dispose();
    phone.dispose();
    pass.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Form(
                key: formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: 8),
                    const _GradientTitle('Register'),
                    const SizedBox(height: 28),

                    _label('Username'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: username,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    _label('Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Please enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    _label('ID card number'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: idCard,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'x xxxx xxxxx xx x',
                      ),
                    ),
                    const SizedBox(height: 14),

                    _label('Phonenumber'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: '099-999-9999'),
                    ),
                    const SizedBox(height: 14),

                    _label('Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: pass,
                      obscureText: obscure1,
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          icon: Icon(obscure1
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() => obscure1 = !obscure1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _label('Confirm-Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: confirm,
                      obscureText: obscure2,
                      validator: (v) =>
                          (v != pass.text) ? 'Password not match' : null,
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          icon: Icon(obscure2
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() => obscure2 = !obscure2),
                        ),
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/forgot'),
                        child: const Text('Forgot password?'),
                      ),
                    ),

                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: loading ? null : _doRegister,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6EA8FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          loading ? 'Please wait...' : 'Continue',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(.7),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            "Login",
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String s) => Text(s, style: const TextStyle(fontSize: 13.5));
}

/* helper */
class _GradientTitle extends StatelessWidget {
  const _GradientTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF2260FF), Color(0xFFFFA8C5)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (rect) => gradient.createShader(rect),
          child: const Text(
            'Register',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 106,
          height: 4,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}
