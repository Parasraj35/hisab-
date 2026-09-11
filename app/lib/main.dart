import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // google_fonts fetches Inter over the network on first use by default —
  // this app is built to make zero network calls at runtime. Falls back to
  // the platform's default font instead of ever reaching out.
  GoogleFonts.config.allowRuntimeFetching = false;

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = kReleaseMode ? 'production' : 'development';
    },
    appRunner: () => runApp(const ProviderScope(child: HisabApp())),
  );
}

class HisabApp extends ConsumerStatefulWidget {
  const HisabApp({super.key});

  @override
  ConsumerState<HisabApp> createState() => _HisabAppState();
}

class _HisabAppState extends ConsumerState<HisabApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounded (home button, app switch, or actually closed) — arms
    // the lock screen for next time, but only if App Lock is on
    // (AuthController.lockIfNeeded checks that).
    if (state == AppLifecycleState.paused) {
      ref.read(authControllerProvider.notifier).lockIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
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
      // Every screen was designed phone-first (a single column filling the
      // available width). Left alone on a tablet or a desktop window,
      // that means form fields and list rows stretch edge-to-edge at 800+
      // logical pixels, which reads as broken rather than "responsive".
      // Capping content to a comfortable reading width and centering it —
      // with the surround painted in the same themed background, not a
      // stray gap — is the standard, low-risk fix: phones (the overwhelming
      // majority of screens) are narrower than the cap and this is a no-op
      // for them; nothing about any individual screen's layout changes.
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final width = MediaQuery.sizeOf(context).width;
        const maxContentWidth = 640.0;
        if (width <= maxContentWidth) return child;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
