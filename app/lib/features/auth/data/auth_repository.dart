import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(apiClientProvider)),
);

class AuthResult {
  const AuthResult({required this.user, this.tokens});
  final UserModel user;
  final AuthTokens? tokens;
}

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<AuthResult> register({
    required String phone,
    required String password,
    String? email,
  }) async {
    final res = await _api.post(ApiEndpoints.register, data: {
      'phone': phone,
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    final data = res['data'] as Map<String, dynamic>;
    return AuthResult(
      user: UserModel.fromJson(Map<String, dynamic>.from(data['user'])),
      tokens: AuthTokens.fromJson(Map<String, dynamic>.from(data['tokens'])),
    );
  }

  Future<AuthResult> login(
      {required String identifier, required String password}) async {
    final res = await _api.post(ApiEndpoints.login,
        data: {'identifier': identifier, 'password': password});
    final data = res['data'] as Map<String, dynamic>;
    return AuthResult(
      user: UserModel.fromJson(Map<String, dynamic>.from(data['user'])),
      tokens: AuthTokens.fromJson(Map<String, dynamic>.from(data['tokens'])),
    );
  }

  Future<UserModel> me() async {
    final res = await _api.get(ApiEndpoints.me);
    return UserModel.fromJson(Map<String, dynamic>.from(res['data']['user']));
  }

  Future<UserModel> profileSetup({
    required String fullName,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    final res = await _api.patch(ApiEndpoints.profileSetup, data: {
      'fullName': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return UserModel.fromJson(Map<String, dynamic>.from(res['data']['user']));
  }

  Future<AccountModel> accountSetup({
    required String name,
    required String currency,
    required double initialBalance,
    String type = 'cash',
  }) async {
    final res = await _api.post(ApiEndpoints.accountSetup, data: {
      'name': name,
      'currency': currency,
      'initialBalance': initialBalance,
      'type': type,
    });
    return AccountModel.fromJson(
        Map<String, dynamic>.from(res['data']['account']));
  }

  Future<void> forgotPassword(String email) =>
      _api.post(ApiEndpoints.forgotPassword, data: {'email': email});
}
