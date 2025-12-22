import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _username = TextEditingController();

  bool _isLogin = true;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    final confirm = _confirm.text;
    final username = _username.text.trim();

    if (email.isEmpty || pass.isEmpty) return;

    if (!_isLogin) {
      if (username.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Username is required.")));
        return;
      }
      if (pass != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match.")),
        );
        return;
      }
    }

    if (mounted) setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    auth.clearError();

    if (_isLogin) {
      await auth.login(email: email, password: pass);
    } else {
      await auth.registerWithUsername(
        email: email,
        password: pass,
        username: username,
      );
    }

    if (!mounted) return;

    setState(() => _submitting = false);

    final err = auth.error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? "Login" : "Create account";

    return Scaffold(
      appBar: AppBar(title: const Text("WAYS")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            if (!_isLogin) ...[
              TextField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: "Username (unique)",
                  hintText: "e.g. User123...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            if (!_isLogin) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 12),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isLogin ? "Login" : "Sign up"),
              ),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() => _isLogin = !_isLogin),
              child: Text(
                _isLogin ? "Create an account" : "I already have an account",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
