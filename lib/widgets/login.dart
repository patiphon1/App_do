import 'package:flutter/material.dart';

/* ----------------------------- Shared Widgets ---------------------------- */

class GradientTitle extends StatelessWidget {
  final String text;
  const GradientTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF7C4DFF), Color(0xFF64B5F6)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (rect) => gradient.createShader(rect),
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 92,
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

class ContinueButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const ContinueButton({super.key, this.text = 'Continue', this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF6EA8FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const GoogleButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.g_mobiledata, size: 28),
      label: const Text('Login with Google'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.5);
    return Row(
      children: [
        Expanded(child: Divider(color: c)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Or', style: TextStyle(color: c)),
        ),
        Expanded(child: Divider(color: c)),
      ],
    );
  }
}

/* ------------------------------- Pages ----------------------------------- */

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();
    final pass = TextEditingController();
    bool obscure = true;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const GradientTitle('Login'),
                  const SizedBox(height: 28),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Your Email',
                      hintText: 'tester@gmail.com',
                    ),
                  ),
                  const SizedBox(height: 14),
                  StatefulBuilder(
                    builder: (_, setState) => TextField(
                      controller: pass,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ContinueButton(onPressed: () {
                    // TODO: Firebase Auth
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Login pressed")),
                    );
                  }),
                  const SizedBox(height: 18),
                  const OrDivider(),
                  const SizedBox(height: 18),
                  GoogleButton(onPressed: () {}),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don’t have an account? "),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        ),
                        child: const Text(
                          "Sign up",
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
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
    );
  }
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final username = TextEditingController();
    final email = TextEditingController();
    final idCard = TextEditingController();
    final phone = TextEditingController();
    final pass = TextEditingController();
    final confirm = TextEditingController();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const GradientTitle('Register'),
                  const SizedBox(height: 28),
                  TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
                  const SizedBox(height: 14),
                  TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 14),
                  TextField(controller: idCard, decoration: const InputDecoration(labelText: 'ID card number')),
                  const SizedBox(height: 14),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone number')),
                  const SizedBox(height: 14),
                  TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                  const SizedBox(height: 14),
                  TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm-Password')),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ContinueButton(onPressed: () {
                    // TODO: Firebase Auth createUser
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Register pressed")),
                    );
                  }),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "Login",
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
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
    );
  }
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Enter your email to reset password"),
            const SizedBox(height: 14),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 20),
            ContinueButton(
              text: "Send Reset Link",
              onPressed: () {
                // TODO: Firebase Auth sendPasswordResetEmail
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reset link sent (mock)")),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
