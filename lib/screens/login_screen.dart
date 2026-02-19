import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailOrUsernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  String? _error;

  Future<void> _doLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final emailOrUsername = _emailOrUsernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (emailOrUsername.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Please enter email/username and password.';
      });
      return;
    }

    try {
      await _auth.login(
        emailOrUsername: emailOrUsername,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailOrUsernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailOrUsernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Email or Username',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
              onSubmitted: (_) => _loading ? null : _doLogin(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _doLogin,
              child: _loading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Login'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
