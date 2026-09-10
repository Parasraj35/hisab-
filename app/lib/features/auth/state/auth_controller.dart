import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  needsProfile,
  needsAccount,
  authenticated
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.loading = false,
    this.error,
  });

  final AuthStatus status;
  final UserModel? user;
  final bool loading;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController(
          ref.read(authRepositoryProvider),
          ref.read(tokenStorageProvider),
        ));

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, this._storage) : super(const AuthState());

  final AuthRepository _repo;
  final TokenStorage _storage;

  AuthStatus _stageToStatus(UserModel user) {
    switch (user.onboardingStage) {
      case 'account':
        return AuthStatus.needsAccount;
      case 'done':
        return AuthStatus.authenticated;
      default:
        return AuthStatus.needsProfile;
    }
  }

  /// Called by the splash screen.
  Future<void> restoreSession() async {
    final token = await _storage.accessToken;
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _repo.me();
      state = state.copyWith(status: _stageToStatus(user), user: user);
    } catch (_) {
      await _storage.clear();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> register(
          {required String phone, required String password, String? email}) =>
      _run(() async {
        final result = await _repo.register(
            phone: phone, password: password, email: email);
        await _storage.saveTokens(
          access: result.tokens!.accessToken,
          refresh: result.tokens!.refreshToken,
        );
        state = state.copyWith(
          status: _stageToStatus(result.user),
          user: result.user,
        );
      });

  Future<bool> login({required String identifier, required String password}) =>
      _run(() async {
        final result =
            await _repo.login(identifier: identifier, password: password);
        await _storage.saveTokens(
          access: result.tokens!.accessToken,
          refresh: result.tokens!.refreshToken,
        );
        state = state.copyWith(
            status: _stageToStatus(result.user), user: result.user);
      });

  Future<bool> saveProfile({
    required String fullName,
    String? email,
    String? phone,
    String? avatarUrl,
  }) =>
      _run(() async {
        final user = await _repo.profileSetup(
            fullName: fullName,
            email: email,
            phone: phone,
            avatarUrl: avatarUrl);
        state = state.copyWith(status: _stageToStatus(user), user: user);
      });

  Future<bool> saveFirstAccount({
    required String name,
    required String currency,
    required double initialBalance,
    String type = 'cash',
  }) =>
      _run(() async {
        await _repo.accountSetup(
            name: name,
            currency: currency,
            initialBalance: initialBalance,
            type: type);
        state = state.copyWith(status: AuthStatus.authenticated);
      });

  Future<void> logout() async {
    await _storage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await action();
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }
}
