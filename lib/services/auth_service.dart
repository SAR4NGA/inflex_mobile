import 'token_store.dart';
import 'api_client.dart';

class AuthService {
  final _tokenStore = TokenStore();

  Future<String> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final data = await ApiClient.post(
      'api/auth/login',
      body: {
        'emailOrUsername': emailOrUsername,
        'password': password,
      },
      withAuth: false,
    );

    final token = data['token'] as String;
    await _tokenStore.saveToken(token);
    return token;
  }
}
