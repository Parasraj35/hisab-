import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/ads/app_open_ad_manager.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/settings/data/settings_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  MobileAds.instance.initialize();
  AppOpenAdManager.instance.loadAd();
  runApp(const ProviderScope(child: HisabApp()));
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
