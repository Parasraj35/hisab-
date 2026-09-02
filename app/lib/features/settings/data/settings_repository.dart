import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class BackupInfo {
  const BackupInfo({
    required this.id,
    required this.sizeBytes,
    required this.createdAt,
    required this.counts,
  });

  final String id;
  final int sizeBytes;
  final DateTime createdAt;
  final Map<String, dynamic> counts;

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024)
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get transactionCount => (counts['transactions'] ?? 0) as int;

  factory BackupInfo.fromJson(Map<String, dynamic> json) => BackupInfo(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        sizeBytes: (json['sizeBytes'] ?? 0) as int,
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString())
                ?.toLocal() ??
            DateTime.now(),
        counts: Map<String, dynamic>.from(json['counts'] ?? {}),
      );
}

class SecurityStatus {
  const SecurityStatus({
    required this.hasPin,
    required this.appLock,
    required this.biometricUnlock,
    required this.twoStepVerification,
    required this.autoLockMinutes,
  });

  final bool hasPin;
  final bool appLock;
  final bool biometricUnlock;
  final bool twoStepVerification;
  final int autoLockMinutes;

  factory SecurityStatus.fromJson(Map<String, dynamic> json) => SecurityStatus(
        hasPin: json['hasPin'] == true,
        appLock: json['appLock'] == true,
        biometricUnlock: json['biometricUnlock'] == true,
        twoStepVerification: json['twoStepVerification'] == true,
        autoLockMinutes: (json['autoLockMinutes'] ?? 1) as int,
      );
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => SettingsRepository(ref.read(apiClientProvider)));

class SettingsRepository {
  SettingsRepository(this._api);
  final ApiClient _api;

  Future<void> updateProfile(Map<String, dynamic> changes) =>
      _api.patch(ApiEndpoints.updateProfile, data: changes);

  Future<String> uploadAvatar(String filePath) async {
    final res = await _api.uploadFile(ApiEndpoints.uploadAvatar,
        fieldName: 'avatar', filePath: filePath);
    return res['data']['avatarUrl'] as String;
  }

  Future<Map<String, dynamic>> updateSettings(
      Map<String, dynamic> changes) async {
    final res = await _api.patch(ApiEndpoints.updateSettings, data: changes);
    return Map<String, dynamic>.from(res['data']['settings']);
  }

  Future<void> changePassword(String current, String next) =>
      _api.post(ApiEndpoints.changePassword,
          data: {'currentPassword': current, 'newPassword': next});

  Future<SecurityStatus> security() async {
    final res = await _api.get(ApiEndpoints.securityStatus);
    return SecurityStatus.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<void> setPin(String pin, {String? currentPin}) => _api.post(
        ApiEndpoints.pin,
        data: {'pin': pin, if (currentPin != null) 'currentPin': currentPin},
      );

  Future<void> removePin() => _api.delete(ApiEndpoints.pin);

  Future<List<BackupInfo>> backups() async {
    final res = await _api.get(ApiEndpoints.backups);
    return (res['data']['backups'] as List)
        .map((e) => BackupInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createBackup() => _api.post(ApiEndpoints.backups);
  Future<void> restoreBackup(String id) =>
      _api.post(ApiEndpoints.backupRestore(id));
  Future<void> deleteBackup(String id) => _api.delete(ApiEndpoints.backup(id));
}

final securityProvider = FutureProvider<SecurityStatus>(
    (ref) => ref.read(settingsRepositoryProvider).security());

final backupsProvider = FutureProvider<List<BackupInfo>>(
    (ref) => ref.read(settingsRepositoryProvider).backups());

/// Drives ThemeMode across the app (screen 28).
final themeModeProvider = StateProvider<String>((ref) => 'system');
