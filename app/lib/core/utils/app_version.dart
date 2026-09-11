import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Real, live app version (was hardcoded as "1.0.0" in three separate
/// screens — guaranteed to drift out of date the next time pubspec.yaml's
/// version bumps and someone forgets to also update those strings).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
