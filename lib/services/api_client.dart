import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'token_store.dart';

class ApiClient {
  static Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final token = await TokenStore().getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<dynamic> get(String path, {bool withAuth = true}) async {
    final res = await http.get(_uri(path), headers: await _headers(withAuth: withAuth));
    return _handle(res);
  }

  static Future<dynamic> post(String path, {Object? body, bool withAuth = true}) async {
    final res = await http.post(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = res.body;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw Exception('HTTP ${res.statusCode}: ${data ?? res.reasonPhrase}');
  }
}
