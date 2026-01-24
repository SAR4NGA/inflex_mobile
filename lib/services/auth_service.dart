import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'token_store.dart';

class AuthService {
  final _tokenStore = TokenStore();

  Future<String> login(String userId) async {
    final url = Uri.parse('${AppConfig.baseUrl}api/auth/login');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Login failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['token'] as String;

    await _tokenStore.saveToken(token);
    return token;
  }
}
