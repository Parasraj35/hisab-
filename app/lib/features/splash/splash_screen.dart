import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/brand_mark.dart';
import '../auth/state/auth_controller.dart';

/// Screen 1 — Splash
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  // Staggered rather than simultaneous — the mark settles first, then the
  // wordmark, then the tagline and progress bar follow it in.
  late final Animation<double> _markScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
  );
  late final Animation<double> _markFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
  );
  late final Animation<double> _titleFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
  );
  late final Animation<Offset> _titleSlide = Tween<Offset>(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.65, curve: Curves.easeOutCubic)));
  late final Animation<double> _taglineFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
  );
  late final Animation<double> _progressFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    // Minimum 1.6s brand moment, then resolve where the user belongs.
    // (The App Open ad is triggered later, from DashboardScreen — see
    // AppOpenAdManager for why it's kept off the splash-to-dashboard path.)
    Future.wait([
      ref.read(authControllerProvider.notifier).restoreSession(),
      Future.delayed(const Duration(milliseconds: 1600)),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.header,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Diagonal depth instead of a flat fill — the same gradient
            // language Clay.fill uses on cards elsewhere in the app.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.header, AppColors.forestDeep],
                ),
              ),
            ),
            // Two soft ambient glows, off-center for asymmetric depth rather
            // than a perfectly centered, template-shaped layout.
            Positioned(
              top: -120,
              right: -80,
              child: _Glow(color: AppColors.accent, size: 320, opacity: 0.16),
            ),
            Positioned(
              bottom: -140,
              left: -100,
              child: _Glow(color: AppColors.accent, size: 380, opacity: 0.12),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _markFade,
                      child: ScaleTransition(
                        scale: _markScale,
                        child: const BrandMark(size: 104),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: const Text('HISAB', style: AppTypography.brand),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: _taglineFade,
                      child: Text(
                        'Manage Money.\nMake Better Decisions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 72),
                    FadeTransition(
                      opacity: _progressFade,
                      child: const _LoadingBar(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(opacity), color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}

/// A slim indeterminate bar — replaces the generic spinner-and-caption
/// pattern with something that reads as a single considered brand moment.
class _LoadingBar extends StatefulWidget {
  const _LoadingBar();

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.14)),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Align(
              alignment: Alignment(_controller.value * 4 - 2, 0),
              child: FractionallySizedBox(
                widthFactor: 0.4,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
