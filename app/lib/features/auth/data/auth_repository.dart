import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(apiClientProvider)),
);

class AuthResult {
  const AuthResult({required this.user, this.tokens, this.devOtpCode});
  final UserModel user;
  final AuthTokens? tokens;
  final String? devOtpCode;
}

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<AuthResult> register({
    required String email,
    required String password,
    String? phone,
  }) async {
    final res = await _api.post(ApiEndpoints.register,
        data: {'email': email, 'password': password, if (phone != null) 'phone': phone});
    final data = res['data'] as Map<String, dynamic>;
    return AuthResult(
      user: UserModel.fromJson(Map<String, dynamic>.from(data['user'])),
      tokens: AuthTokens.fromJson(Map<String, dynamic>.from(data['tokens'])),
      devOtpCode: (data['otp'] ?? {})['devCode']?.toString(),
    );
  }

  Future<AuthResult> login({required String identifier, required String password}) async {
    final res = await _api
        .post(ApiEndpoints.login, data: {'identifier': identifier, 'password': password});
    final data = res['data'] as Map<String, dynamic>;
    return AuthResult(
      user: UserModel.fromJson(Map<String, dynamic>.from(data['user'])),
      tokens: AuthTokens.fromJson(Map<String, dynamic>.from(data['tokens'])),
    );
  }

  Future<AuthResult> googleAuth({required String idToken}) async {
    final res = await _api.post(ApiEndpoints.googleAuth, data: {'idToken': idToken});
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

  Future<UserModel> verifyOtp(String code) async {
    final res = await _api.post(ApiEndpoints.verifyOtp, data: {'code': code});
    return UserModel.fromJson(Map<String, dynamic>.from(res['data']['user']));
  }

  Future<String?> resendOtp() async {
    final res = await _api.post(ApiEndpoints.resendOtp);
    return (res['data']['otp'] ?? {})['devCode']?.toString();
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
    return AccountModel.fromJson(Map<String, dynamic>.from(res['data']['account']));
  }

  Future<void> forgotPassword(String email) =>
      _api.post(ApiEndpoints.forgotPassword, data: {'email': email});
}
