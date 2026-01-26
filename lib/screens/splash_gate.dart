import 'package:flutter/material.dart';
import '../services/token_store.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _decideNextScreen();
  }

  Future<void> _decideNextScreen() async {
    // 1) Read token from secure storage
    final store = TokenStore();
    final token = await store.getToken();

    // 2) If this widget unmounted while awaiting, stop
    if (!mounted) return;

    // 3) Navigate based on token existence
    if (token != null && token.isNotEmpty) {
      // Token exists -> Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // No token -> Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple loading UI while we check storage
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
