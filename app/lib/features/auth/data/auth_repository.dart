import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/app_database.dart';
import 'auth_models.dart';

const _profileId = 'local';

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository());

/// Backs the single local "profile" row — there is no account to log into,
/// so this replaces what used to be a server-authenticated user record.
class ProfileRepository {
  Future<UserModel?> getUser() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [_profileId]);
    if (rows.isEmpty) return null;
    return UserModel.fromJson(_toJson(rows.first));
  }

  /// Called once, from Profile Setup — creates the row if this is the first
  /// launch, or updates it if the user is re-running setup. Always advances
  /// onboarding past the "profile" stage, mirroring the old
  /// PATCH /auth/profile-setup behaviour.
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
      await db.insert('profile', {
        'id': _profileId,
        'full_name': fullName,
        'email': email ?? '',
        'phone': phone ?? '',
        'avatar_path': avatarPath ?? '',
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
