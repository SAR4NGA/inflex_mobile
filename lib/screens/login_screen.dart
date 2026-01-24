import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController(text: 'test-user');
  final _auth = AuthService();

  bool _loading = false;
  String? _tokenOrError;

  Future<void> _doLogin() async {
    setState(() {
      _loading = true;
      _tokenOrError = null;
    });

    try {
      final token = await _auth.login(_controller.text.trim());
      setState(() => _tokenOrError = token);
    } catch (e) {
      setState(() => _tokenOrError = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'User ID',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _doLogin,
              child: _loading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(),
              )
                  : const Text('Login'),
            ),
            const SizedBox(height: 16),
            if (_tokenOrError != null)
              SelectableText(
                _tokenOrError!,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
