import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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
    with TickerProviderStateMixin {
  // The mark gets its own spring-driven controller — real motion, not an
  // eased curve — so it settles with a small, physical overshoot instead of
  // arriving mechanically on schedule. Bound wide enough that the overshoot
  // itself is never clamped.
  late final AnimationController _markController = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 1.3,
  );

  // A second, independent loop starts once the spring settles — a slow,
  // barely-there breathing pulse so the mark reads as alive, not a frozen
  // frame that happens to have finished animating in.
  late final AnimationController _breathController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final Animation<double> _breath = Tween<double>(begin: 1.0, end: 1.035)
      .animate(
          CurvedAnimation(parent: _breathController, curve: Curves.easeInOut));

  // Text and progress bar still use a conventional staggered timeline —
  // it's the mark that needed to feel physical, not the copy.
  late final AnimationController _textController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  // The mark's opacity rides this bounded timeline too — its own controller
  // is spring-driven and legitimately overshoots past 1.0, which an
  // Interval curve can't safely sit on top of.
  late final Animation<double> _markFade = CurvedAnimation(
    parent: _textController,
    curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
  );
  late final Animation<double> _titleFade = CurvedAnimation(
    parent: _textController,
    curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
  );
  late final Animation<Offset> _titleSlide = Tween<Offset>(
    begin: const Offset(0, 0.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic)));
  late final Animation<double> _taglineFade = CurvedAnimation(
    parent: _textController,
    curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
  );
  late final Animation<double> _progressFade = CurvedAnimation(
    parent: _textController,
    curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();

    _markController.animateWith(
      SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 140, damping: 11),
          0,
          1,
          0),
    );
    // The spring settles by ~900ms; a fixed delay is simpler and more
    // reliable here than trying to detect "at rest" from a bounded
    // AnimationStatus, which doesn't map cleanly onto spring overshoot.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _breathController.repeat(reverse: true);
    });

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
    _markController.dispose();
    _breathController.dispose();
    _textController.dispose();
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
            // A page of ruled ledger lines, almost invisible — the one visual
            // idea that's actually *about* HISAB (an account book) rather
            // than a stock fintech-gradient backdrop.
            const Positioned.fill(
                child: IgnorePointer(
                    child: CustomPaint(painter: _LedgerPainter()))),
            // Corners settle a shade darker than the center — depth from
            // tone, not a bolted-on accent-colored glow.
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.2),
                      radius: 1.15,
                      colors: [Colors.transparent, Color(0x33000000)],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // Weighted 5:4 rather than a dead-centered 1:1 split —
                    // the mark sits slightly above center, the way a hand
                    // laying this out would favor the upper two-thirds.
                    const Spacer(flex: 5),
                    AnimatedBuilder(
                      animation: Listenable.merge(
                          [_markController, _breathController]),
                      builder: (context, child) => FadeTransition(
                        opacity: _markFade,
                        child: Transform.scale(
                          scale: _markController.value * _breath.value,
                          child: child,
                        ),
                      ),
                      child: const BrandMark(size: 104),
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
                    const Spacer(flex: 4),
                    FadeTransition(
                        opacity: _progressFade, child: const _LoadingBar()),
                    const SizedBox(height: 28),
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

/// Faint horizontal ledger rules across the full screen, with a narrow
/// margin rule near the left edge — the two marks that make a blank page
/// read as an account book rather than plain paper.
class _LedgerPainter extends CustomPainter {
  const _LedgerPainter();

  static const _rowHeight = 34.0;
  static const _marginX = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    for (double y = size.height * 0.1; y < size.height; y += _rowHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    canvas.drawLine(
      Offset(_marginX, 0),
      Offset(_marginX, size.height),
      Paint()
        ..color = AppColors.accent.withOpacity(0.10)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
