import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart'; // Service  Auth
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscure = true;
  bool loading = false;

  void _show(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _doLogin() async {
    if (!formKey.currentState!.validate()) return;
    if (loading) return; // กันกดรัว
    setState(() => loading = true);
    try {
      await AuthService.instance.signIn(email.text.trim(), pass.text);
      if (!mounted) return;
      // นำทางไปหน้า Home และล้างสแตกกันย้อนกลับมาหน้า Login
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _show(mapAuthError(e));
    } catch (e) {
      if (!mounted) return;
      _show('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
                    const _GradientTitle('Login'),
                    const SizedBox(height: 28),

                    // Email
                    const Text('Your Email', style: TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'กรุณากรอกอีเมลให้ถูกต้อง'
                          : null,
                      decoration:
                          const InputDecoration(hintText: 'tester@gmail.com'),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    const Text('Password', style: TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: pass,
                      obscureText: obscure,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'รหัสผ่านอย่างน้อย 6 ตัวอักษร'
                          : null,
                      decoration: InputDecoration(
                        hintText: '••••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                      ),
                    ),

                    // Forgot
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/forgot'),
                        child: const Text('Forgot password?'),
                      ),
                    ),

                    // Continue button
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: loading ? null : _doLogin,
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

                    const SizedBox(height: 18),

                    // Bottom text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don’t have an account? ",
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(.7),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: const Text(
                            "Sign up",
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 400),
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

/* ------------------------------ helper UI ------------------------------- */

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
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 86,
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
