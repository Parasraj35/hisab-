import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/app_database.dart';
import '../../accounts/data/account_repository.dart';
import '../../categories/data/category_repository.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, needsProfile, needsAccount, authenticated }

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
          ref.read(profileRepositoryProvider),
          ref.read(accountRepositoryProvider),
          ref.read(categoryRepositoryProvider),
        ));

/// Despite the name (kept to avoid rippling a rename through every screen
/// that reads it), this no longer authenticates anything — there is no
/// server, no token, nothing to log into. It just tracks whether the local
/// profile/onboarding has been completed, sourced entirely from the local
/// DB instead of a JWT session.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._profileRepo, this._accountRepo, this._categoryRepo)
      : super(const AuthState());

  final ProfileRepository _profileRepo;
  final AccountRepository _accountRepo;
  final CategoryRepository _categoryRepo;

  AuthStatus _stageToStatus(UserModel? user) {
    if (user == null) return AuthStatus.needsProfile;
    switch (user.onboardingStage) {
      case 'account':
        return AuthStatus.needsAccount;
      case 'done':
        return AuthStatus.authenticated;
      default:
        return AuthStatus.needsProfile;
    }
  }

  /// Called by the splash screen — the local equivalent of "restore session".
  Future<void> restoreSession() async {
    final user = await _profileRepo.getUser();
    state = state.copyWith(status: _stageToStatus(user), user: user);
  }

  Future<bool> saveProfile({
    required String fullName,
    String? email,
    String? phone,
    String? avatarUrl,
  }) =>
      _run(() async {
        final isFirstLaunch = (await _profileRepo.getUser()) == null;
        final user = await _profileRepo.saveProfile(
          fullName: fullName,
          email: email,
          phone: phone,
          avatarPath: avatarUrl,
        );
        if (isFirstLaunch) await _categoryRepo.seedDefaults();
        state = state.copyWith(status: _stageToStatus(user), user: user);
      });

  Future<bool> saveFirstAccount({
    required String name,
    required String currency,
    required double initialBalance,
    String type = 'cash',
  }) =>
      _run(() async {
        await _accountRepo.create(
            name: name, type: type, currency: currency, initialBalance: initialBalance);
        await _profileRepo.completeAccountSetup(currency: currency);
        final user = await _profileRepo.getUser();
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      });

  /// Repurposed from "log out" — there's no account to sign back into, so
  /// this is now a full local reset: wipe every table and send the user
  /// back through onboarding. Used by the "Reset App Data" action.
  Future<void> resetAppData() async {
    await AppDatabase.instance.wipeAllData();
    state = const AuthState(status: AuthStatus.needsProfile);
  }

  /// Compatibility alias for screens not yet updated to the new name/copy —
  /// see resetAppData().
  Future<void> logout() => resetAppData();

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
