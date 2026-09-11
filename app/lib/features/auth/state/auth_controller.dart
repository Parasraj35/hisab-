import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/app_database.dart';
import '../../accounts/data/account_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../settings/data/settings_repository.dart';
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
    this.isLocked = false,
  });

  final AuthStatus status;
  final UserModel? user;
  final bool loading;
  final String? error;
  // Separate from `status` — a user can be fully `authenticated` and still
  // locked behind PIN/biometric after the app was backgrounded. Only ever
  // true when the "App Lock" setting is actually on.
  final bool isLocked;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? isLocked,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        isLocked: isLocked ?? this.isLocked,
      );
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController(
          ref.read(profileRepositoryProvider),
          ref.read(accountRepositoryProvider),
          ref.read(categoryRepositoryProvider),
          ref.read(settingsRepositoryProvider),
        ));

/// There's no server behind this — "login" is a phone+password check
/// against the one local profile row, and "session" is just an
/// is_logged_in flag on that row. Everything else (profile/account
/// onboarding) is unchanged from the local-only rewrite.
class AuthController extends StateNotifier<AuthState> {
  AuthController(
      this._profileRepo, this._accountRepo, this._categoryRepo, this._settingsRepo)
      : super(const AuthState());

  final ProfileRepository _profileRepo;
  final AccountRepository _accountRepo;
  final CategoryRepository _categoryRepo;
  final SettingsRepository _settingsRepo;

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

  /// Called by the splash screen. No account yet, or logged out → the
  /// Login/Sign Up screens. Otherwise resume wherever onboarding left off —
  /// locked behind PIN/biometric first if App Lock is on, same as if the
  /// app had just been brought back from the background.
  Future<void> restoreSession() async {
    final user = await _profileRepo.getUser();
    if (user == null || !await _profileRepo.isLoggedIn()) {
      state = state.copyWith(status: AuthStatus.unauthenticated, user: user);
      return;
    }
    final status = _stageToStatus(user);
    final locked = status == AuthStatus.authenticated && await _appLockEnabled();
    state = state.copyWith(status: status, user: user, isLocked: locked);
  }

  Future<bool> _appLockEnabled() async {
    try {
      return (await _settingsRepo.security()).appLock;
    } catch (_) {
      return false;
    }
  }

  /// Called when the app is backgrounded (see HisabApp's lifecycle
  /// observer) — the next foreground will show the lock screen, but only
  /// when App Lock is actually turned on; otherwise this is a no-op.
  Future<void> lockIfNeeded() async {
    if (state.status != AuthStatus.authenticated || state.isLocked) return;
    if (await _appLockEnabled()) {
      state = state.copyWith(isLocked: true);
    }
  }

  /// Called by the lock screen after a correct PIN or biometric check.
  void unlock() => state = state.copyWith(isLocked: false);

  Future<bool> register({required String phone, required String password}) =>
      _run(() async {
        final user = await _profileRepo.register(phone: phone, password: password);
        await _categoryRepo.seedDefaults();
        state = state.copyWith(status: _stageToStatus(user), user: user);
      });

  Future<bool> login({required String identifier, required String password}) =>
      _run(() async {
        final user = await _profileRepo.login(phone: identifier, password: password);
        state = state.copyWith(status: _stageToStatus(user), user: user);
      });

  Future<bool> saveProfile({
    required String fullName,
    String? email,
    String? phone,
    String? avatarUrl,
  }) =>
      _run(() async {
        final user = await _profileRepo.saveProfile(
          fullName: fullName,
          email: email,
          phone: phone,
          avatarPath: avatarUrl,
        );
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

  /// The real thing again now that Login exists to sign back into — just
  /// clears the local "logged in" flag, the data stays put.
  Future<void> logout() async {
    await _profileRepo.setLoggedOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Full local reset — wipes every table, including the account itself.
  /// Not wired to any screen right now; kept for a future "erase this
  /// device" action.
  Future<void> resetAppData() async {
    await AppDatabase.instance.wipeAllData();
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
