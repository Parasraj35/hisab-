import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_exception.dart';

const _profileId = 'local';
const _pinKey = 'hisab_pin_hash';

/// App-lock security state — PIN lives in flutter_secure_storage (never in
/// the SQLite file itself), everything else is on the profile row. There's
/// no server, so "Change Password" checks against the same local
/// password_hash Login/Signup use, and there's no meaningful "two-step
/// verification" on a single local device — that toggle was dropped rather
/// than kept as a switch that does nothing.
class SecurityStatus {
  const SecurityStatus({
    required this.hasPin,
    required this.appLock,
    required this.biometricUnlock,
    required this.autoLockMinutes,
  });

  final bool hasPin;
  final bool appLock;
  final bool biometricUnlock;
  final int autoLockMinutes;
}

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository());

class SettingsRepository {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> changes) async {
    final db = await AppDatabase.instance.database;
    final columns = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (changes.containsKey('currency')) columns['currency'] = changes['currency'];
    if (changes.containsKey('theme')) columns['theme'] = changes['theme'];
    if (changes.containsKey('appLock')) {
      columns['app_lock'] = changes['appLock'] == true ? 1 : 0;
    }
    if (changes.containsKey('biometricUnlock')) {
      columns['biometric_unlock'] = changes['biometricUnlock'] == true ? 1 : 0;
    }
    if (changes.containsKey('autoLockMinutes')) {
      columns['auto_lock_minutes'] = changes['autoLockMinutes'];
    }

    await db.update('profile', columns, where: 'id = ?', whereArgs: [_profileId]);
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [_profileId]);
    return rows.isEmpty ? {} : rows.first;
  }

  Future<void> changePassword(String current, String next) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [_profileId]);
    if (rows.isEmpty) throw ApiException('No account found');

    final hash = rows.first['password_hash'] as String? ?? '';
    if (hash.isEmpty || !BCrypt.checkpw(current, hash)) {
      throw ApiException('Current password is incorrect');
    }
    if (current == next) throw ApiException('New password must be different');

    await db.update(
      'profile',
      {
        'password_hash': BCrypt.hashpw(next, BCrypt.gensalt()),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [_profileId],
    );
  }

  Future<SecurityStatus> security() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [_profileId]);
    final hasPin = (await _storage.read(key: _pinKey)) != null;

    if (rows.isEmpty) {
      return SecurityStatus(
          hasPin: hasPin, appLock: false, biometricUnlock: false, autoLockMinutes: 1);
    }
    final row = rows.first;
    return SecurityStatus(
      hasPin: hasPin,
      appLock: row['app_lock'] == 1,
      biometricUnlock: row['biometric_unlock'] == 1,
      autoLockMinutes: (row['auto_lock_minutes'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> setPin(String pin, {String? currentPin}) async {
    final existing = await _storage.read(key: _pinKey);
    if (existing != null) {
      if (currentPin == null || !BCrypt.checkpw(currentPin, existing)) {
        throw ApiException('Current PIN is incorrect');
      }
    }
    await _storage.write(key: _pinKey, value: BCrypt.hashpw(pin, BCrypt.gensalt()));
  }

  Future<bool> verifyPin(String pin) async {
    final hash = await _storage.read(key: _pinKey);
    if (hash == null) return false;
    return BCrypt.checkpw(pin, hash);
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    // App lock and biometric unlock are both meaningless without a PIN.
    final db = await AppDatabase.instance.database;
    await db.update(
      'profile',
      {'app_lock': 0, 'biometric_unlock': 0},
      where: 'id = ?',
      whereArgs: [_profileId],
    );
  }
}

final securityProvider = FutureProvider<SecurityStatus>(
    (ref) => ref.read(settingsRepositoryProvider).security());

/// Drives ThemeMode across the app (screen 28).
final themeModeProvider = StateProvider<String>((ref) => 'system');
