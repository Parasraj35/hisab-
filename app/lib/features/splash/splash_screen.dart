import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ads/app_open_ad_manager.dart';
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
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<double> _scale =
      Tween<double>(begin: 0.82, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    // Minimum 1.6s brand moment, then resolve where the user belongs.
    Future.wait([
      ref.read(authControllerProvider.notifier).restoreSession(),
      Future.delayed(const Duration(milliseconds: 1600)),
    ]).then((_) => AppOpenAdManager.instance.showAdIfAvailable());
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
        statusBarColor: AppColors.forestDeep,
        systemNavigationBarColor: AppColors.forestDeep,
      ),
      child: Scaffold(
        backgroundColor: AppColors.forestDeep,
        body: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(scale: _scale, child: const BrandMark(size: 104)),
                const SizedBox(height: 28),
                const Text('HISAB', style: AppTypography.brand),
                const SizedBox(height: 10),
                Text(
                  'Manage Money.\nMake Better Decisions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 64),
                SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Loading...',
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
