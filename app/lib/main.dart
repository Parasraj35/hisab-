import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/settings/data/settings_repository.dart';

// A DSN is write-only by design (send crash reports, nothing else) — safe
// to commit, same as the AdMob IDs elsewhere in this file's neighborhood.
const _sentryDsn =
    'https://c7b5ac38d6b533683a6112da77075089@o4512056645582848.ingest.us.sentry.io/4512056661508096';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = kReleaseMode ? 'production' : 'development';
    },
    appRunner: () => runApp(const ProviderScope(child: HisabApp())),
  );
}

class HisabApp extends ConsumerWidget {
  const HisabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Screen 28 — the user's saved theme wins; falls back to the OS setting.
    // Seeded from the server on login, then held locally so toggling is instant.
    ref.listen(authControllerProvider, (previous, next) {
      final saved = next.user?.themePreference;
      if (saved != null && saved != ref.read(themeModeProvider)) {
        ref.read(themeModeProvider.notifier).state = saved;
      }
    });

    final themeMode = switch (ref.watch(themeModeProvider)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'HISAB',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
