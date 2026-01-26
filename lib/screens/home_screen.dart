import 'package:flutter/material.dart';
import '../services/token_store.dart';
import 'login_screen.dart';
import '../services/api_client.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final store = TokenStore();
    await store.clear();


    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
          IconButton(
            icon: const Icon(Icons.verified_user),
            onPressed: () async {
              try {
                final data = await ApiClient.get('api/auth/me');
                if (!context.mounted) return;

                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('GET /api/auth/me'),
                    content: Text(data.toString()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      )
                    ],
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;

                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('API Error'),
                    content: Text(e.toString()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      )
                    ],
                  ),
                );
              }
            },
          ),

        ],
      ),
      body: const Center(
        child: Text(
          'You are logged in.\nNext: Transactions list.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
