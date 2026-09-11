import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_exception.dart';
import 'auth_models.dart';

const _profileId = 'local';

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository());

/// Backs the single local "profile" row. There's no server to authenticate
/// against, so "login" here just means: does this device know the phone +
/// password that were set on it at signup. Only one profile row can ever
/// exist — this is a single-user, single-device app.
class ProfileRepository {
  Future<UserModel?> getUser() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [_profileId]);
    if (rows.isEmpty) return null;
    return UserModel.fromJson(_toJson(rows.first));
  }

  Future<bool> hasAccount() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [_profileId]);
    return rows.isNotEmpty;
  }

  Future<bool> isLoggedIn() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile',
        columns: ['is_logged_in'], where: 'id = ?', whereArgs: [_profileId]);
    if (rows.isEmpty) return false;
    return rows.first['is_logged_in'] == 1;
  }

  /// Called from Sign Up — creates the one local account this device will
  /// ever have. Mirrors the old POST /auth/register: hash the password,
  /// create the row, start onboarding at "profile".
  Future<UserModel> register({
    required String phone,
    required String password,
  }) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query('profile', where: 'id = ?', whereArgs: [_profileId]);
    if (existing.isNotEmpty) {
      throw ApiException(
          'An account already exists on this device. Please log in instead.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('profile', {
      'id': _profileId,
      'phone': phone,
      'password_hash': BCrypt.hashpw(password, BCrypt.gensalt()),
      'is_logged_in': 1,
      'onboarding_stage': 'profile',
      'created_at': now,
      'updated_at': now,
    });

    return (await getUser())!;
  }

  /// Called from Login — verifies the phone + password against the single
  /// local account and marks this device "logged in" again.
  Future<UserModel> login({
    required String phone,
    required String password,
  }) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [_profileId]);
    if (rows.isEmpty) {
      throw ApiException('No account found on this device. Please sign up.');
    }

    final row = rows.first;
    if ((row['phone'] as String? ?? '') != phone) {
      throw ApiException('No account found for those details');
    }
    final hash = row['password_hash'] as String? ?? '';
    if (hash.isEmpty || !BCrypt.checkpw(password, hash)) {
      throw ApiException('Incorrect password');
    }

    await db.update(
      'profile',
      {'is_logged_in': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [_profileId],
    );

    return (await getUser())!;
  }

  Future<void> setLoggedOut() async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'profile',
      {'is_logged_in': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [_profileId],
    );
  }

  /// Called from Profile Setup — the row already exists (register() created
  /// it), so this just fills in the rest and advances onboarding past
  /// "profile", mirroring the old PATCH /auth/profile-setup behaviour.
  Future<UserModel> saveProfile({
    required String fullName,
    String? email,
    String? phone,
    String? avatarPath,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await db.query('profile', where: 'id = ?', whereArgs: [_profileId]);

    if (existing.isEmpty) {
      // Defensive fallback only — in the normal flow register() always
      // creates the row first.
      await db.insert('profile', {
        'id': _profileId,
        'full_name': fullName,
        'email': email ?? '',
        'phone': phone ?? '',
        'avatar_path': avatarPath ?? '',
        'is_logged_in': 1,
        'onboarding_stage': 'account',
        'created_at': now,
        'updated_at': now,
      });
    } else {
      final row = existing.first;
      await db.update(
        'profile',
        {
          'full_name': fullName,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (avatarPath != null) 'avatar_path': avatarPath,
          // Only the initial setup pass advances the stage — an edit made
          // later (from the Profile screen) must not regress or re-advance it.
          'onboarding_stage':
              row['onboarding_stage'] == 'profile' ? 'account' : row['onboarding_stage'],
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [_profileId],
      );
    }

    return (await getUser())!;
  }

  /// Called once, from Account Setup — marks onboarding complete and seeds
  /// the currency chosen alongside the first account.
  Future<void> completeAccountSetup({required String currency}) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'profile',
      {
        'currency': currency,
        'onboarding_stage': 'done',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [_profileId],
    );
  }

  Map<String, dynamic> _toJson(Map<String, dynamic> row) => {
        '_id': row['id'],
        'fullName': row['full_name'],
        'email': row['email'],
        'phone': row['phone'],
        'avatarUrl': row['avatar_path'],
        'isVerified': true,
        'onboardingStage': row['onboarding_stage'],
        'settings': {
          'currency': row['currency'],
          'theme': row['theme'],
        },
      };
}
