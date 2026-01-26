import 'token_store.dart';
import 'api_client.dart';

class AuthService {
  final _tokenStore = TokenStore();

  Future<String> login(String userId) async {
    final data = await ApiClient.post(
      'api/auth/login',
      body: {'userId': userId},
      withAuth: false,
    );

    final token = data['token'] as String;
    await _tokenStore.saveToken(token);
    return token;
  }
}
