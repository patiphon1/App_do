import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart';
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
  bool obscure1 = true, obscure2 = true, loading = false;

  // ---- password helpers ----
  bool isStrongPassword(String v) {
    final hasMinLen = v.length >= 8;
    final hasLower = RegExp(r'[a-z]').hasMatch(v);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    final hasSpec = RegExp(r'[!@#\$%\^&\*\(\)_\+\-=\[\]{};:"\\|,.<>\/?~`]').hasMatch(v);
    return hasMinLen && hasLower && hasUpper && hasDigit && hasSpec;
  }
  int passwordScore(String v) {
    int s = 0;
    if (v.length >= 8) s++;
    if (v.length >= 12) s++;
    if (RegExp(r'[a-z]').hasMatch(v)) s++;
    if (RegExp(r'[A-Z]').hasMatch(v)) s++;
    if (RegExp(r'\d').hasMatch(v)) s++;
    if (RegExp(r'[!@#\$%\^&\*\(\)_\+\-=\[\]{};:"\\|,.<>\/?~`]').hasMatch(v)) s++;
    return s.clamp(0, 6);
  }

  // ---- normalize & mask ----
  String _onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');
  String maskThaiId(String raw13) {
    if (raw13.length != 13) return '';
    return '${raw13.substring(0,1)} xxxx xxxxx xx ${raw13.substring(12)}';
  }

  void _show(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _doRegister() async {
  if (!formKey.currentState!.validate()) return;
  setState(() => loading = true);

  User? createdUser;
  try {
    // สมัคร Auth
    final cred = await AuthService.instance.signUp(
      email.text.trim(),
      pass.text,
      displayName: username.text.trim(),
    );
    createdUser = cred.user;

    // เตรียมค่าล้วน
    String _onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');
    String maskThaiId(String raw13) =>
        (raw13.length == 13) ? '${raw13.substring(0,1)} xxxx xxxxx xx ${raw13.substring(12)}' : '';

    final rawId    = _onlyDigits(idCard.text);
    final rawPhone = _onlyDigits(phone.text);

    // 🔁 เรียก repository แบบ "คืน result" ไม่ throw ใน txn
    final result = await UserRepository.instance.createWithUniques(
      AppUser(
        uid: createdUser!.uid,
        email: createdUser.email ?? email.text.trim(),
        displayName: createdUser.displayName ?? username.text.trim(),
        phone: rawPhone,
        idMasked: maskThaiId(rawId),
      ),
      rawIdCard: rawId,
      rawPhone: rawPhone,
    );

    // ถ้าซ้ำ -> ลบผู้ใช้ที่เพิ่งสร้าง + แจ้งข้อความ แล้วจบ
    if (!result.ok) {
      try {
        final cu = FirebaseAuth.instance.currentUser;
        if (createdUser != null && cu != null && cu.uid == createdUser.uid) {
          await cu.delete();
        }
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message ?? 'ข้อมูลซ้ำ')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('สมัครสมาชิกสำเร็จ')),
    );
    // ไปหน้า Home/Gate — อย่า pop กลับหน้า Login เพื่อลดความเสี่ยง sign-out
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  } catch (e) {
    // error อื่น ๆ (ไม่เกี่ยวกับ txn) -> แสดงข้อความตามปกติ โดยไม่ลบ user ทิ้ง
    if (!mounted) return;
    final msg = (e is FirebaseAuthException)
        ? mapAuthError(e)
        : 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } finally {
    if (mounted) setState(() => loading = false);
  }
}

  @override
  void dispose() {
    for (final c in [username,email,idCard,phone,pass,confirm]) { c.dispose(); }
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
                  children: [
                    const SizedBox(height: 8),
                    const _GradientTitle('Register'),
                    const SizedBox(height: 28),

                    _label('Username'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: username,
                      validator: (v) => (v==null||v.trim().isEmpty)?'Required':null,
                    ),
                    const SizedBox(height: 14),

                    _label('Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v==null || !v.contains('@')) ? 'Please enter a valid email' : null,
                    ),
                    const SizedBox(height: 14),

                    _label('ID card number'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: idCard,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'x xxxx xxxxx xx x'),
                      validator: (v) {
                        final raw = _onlyDigits(v ?? '');
                        if (raw.length != 13) return 'ต้องเป็นเลข 13 หลัก';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _label('Phonenumber'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: '099-999-9999'),
                      validator: (v) {
                        final raw = _onlyDigits(v ?? '');
                        if (raw.length != 10 || !raw.startsWith('0')) return 'รูปแบบเบอร์ไม่ถูกต้อง (เช่น 0xxxxxxxxx)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _label('Password'),
                    const SizedBox(height: 6),
                    StatefulBuilder(
                      builder: (context, setLocal) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: pass,
                            obscureText: obscure1,
                            onChanged: (_) => setLocal((){}),
                            validator: (v) {
                              if (v==null || v.isEmpty) return 'Required';
                              if (!isStrongPassword(v)) return '≥8 ตัว และมี a-z, A-Z, 0-9, สัญลักษณ์ อย่างละ 1';
                              // ❌ ตัดเงื่อนไข “ห้ามมีส่วนของอีเมลในรหัสผ่าน”
                              if (username.text.isNotEmpty &&
                                  v.toLowerCase().contains(username.text.trim().toLowerCase())) {
                                return 'ห้ามมีชื่อผู้ใช้ในรหัสผ่าน';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                icon: Icon(obscure1?Icons.visibility_off:Icons.visibility),
                                onPressed: () => setState(() => obscure1 = !obscure1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          LayoutBuilder(
                            builder: (context, c) {
                              final pct = passwordScore(pass.text) / 6.0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: c.maxWidth, height: 8,
                                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6)),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: pct,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: pct < .5 ? Colors.redAccent : pct < .75 ? Colors.orange : Colors.green,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(pct<.5?'รหัสผ่านอ่อน':pct<.75?'ปานกลาง':'แข็งแรง',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7)),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _label('Confirm-Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: confirm,
                      obscureText: obscure2,
                      validator: (v) => (v != pass.text) ? 'Password not match' : null,
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          icon: Icon(obscure2?Icons.visibility_off:Icons.visibility),
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
                        child: Text(loading ? 'Please wait...' : 'Continue', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account? ",
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7))),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text("Login", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                        )
                      ],
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

  Widget _label(String s) => Text(s, style: const TextStyle(fontSize: 13.5));
}

/* helper */
class _GradientTitle extends StatelessWidget {
  const _GradientTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    const g = LinearGradient(colors: [Color(0xFF2260FF), Color(0xFFFFA8C5)]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (rect) => g.createShader(rect),
          child: const Text('Register', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Container(width: 106, height: 4, decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(6))),
      ],
    );
  }
}
