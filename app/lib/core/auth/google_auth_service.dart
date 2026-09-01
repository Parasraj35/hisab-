import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final googleAuthServiceProvider =
    Provider<GoogleAuthService>((ref) => GoogleAuthService());

/// Thrown when Google Sign-In fails or isn't configured for this app build
/// (no OAuth client registered yet).
class GoogleAuthNotAvailable implements Exception {
  const GoogleAuthNotAvailable(this.message);
  final String message;
}

/// Wraps google_sign_in's v7 singleton API. Ready to work the moment a real
/// Google Cloud OAuth client is registered for this app (package name +
/// SHA-1 on Android) — until then, [signIn] surfaces a clear, catchable
/// failure instead of a silent no-op or a fake success.
class GoogleAuthService {
  bool _initialized = false;

  // The Web OAuth client — set as serverClientId so the ID token's audience
  // is the same client the backend verifies against.
  static const _serverClientId =
      '639282272740-3jgrvibj8vicoedn57sneooiscfsvrr4.apps.googleusercontent.com';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      _initialized = true;
    } catch (_) {
      throw const GoogleAuthNotAvailable(
          'Google Sign-In isn\'t set up for this app yet.');
    }
  }

  /// Returns the signed-in Google account's ID token, or throws
  /// [GoogleAuthNotAvailable] if sign-in isn't configured or was cancelled.
  Future<String> signIn() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const GoogleAuthNotAvailable(
            'Google did not return a valid credential.');
      }
      return idToken;
    } on GoogleAuthNotAvailable {
      rethrow;
    } catch (_) {
      throw const GoogleAuthNotAvailable(
          'Google Sign-In isn\'t set up for this app yet.');
    }
  }
}
