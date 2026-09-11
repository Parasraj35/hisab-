import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/ads/interstitial_ad_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../settings/data/settings_repository.dart';
import '../state/auth_controller.dart';

/// Shown whenever the app comes back to the foreground with App Lock on
/// (see AuthController.lockIfNeeded, HisabApp's lifecycle observer). Not a
/// route the user ever navigates to directly — the router forces it
/// whenever AuthState.isLocked is true.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  bool _checking = false;
  bool _biometricTried = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Offer Face/Fingerprint immediately, once, rather than making the
    // user tap a button first when it's already their preferred method.
    if (!_biometricTried) {
      _biometricTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _unlock() async {
    ref.read(authControllerProvider.notifier).unlock();
    // Full-screen ad, mandatory on every unlock — resolves once dismissed
    // (or instantly if none was available, e.g. offline) so the dashboard
    // underneath isn't revealed mid-ad.
    await InterstitialAdManager.instance.showMandatory();
  }

  Future<void> _tryBiometric() async {
    if (!mounted) return;
    final status = await ref.read(securityProvider.future);
    if (!status.biometricUnlock) return;

    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      if (!supported || !canCheck) return;

      final ok = await auth.authenticate(
        localizedReason: 'Unlock HISAB',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok) await _unlock();
    } catch (_) {
      // Fall through to PIN entry — biometric hardware issues shouldn't
      // strand the user outside their own app.
    }
  }

  Future<void> _submitPin() async {
    final pin = _pin.text.trim();
    if (pin.isEmpty) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    final correct = await ref.read(settingsRepositoryProvider).verifyPin(pin);
    if (!mounted) return;

    if (correct) {
      await _unlock();
    } else {
      setState(() {
        _checking = false;
        _error = 'Incorrect PIN';
      });
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);

    return PopScope(
      // No way out but through — this isn't a screen you navigate back
      // from, it's a gate.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.forestDeep,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandMark(size: 72),
                const SizedBox(height: AppSpacing.xl),
                Text('Enter your PIN',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'HISAB is locked for your security',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  label: 'PIN',
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Unlock',
                  loading: _checking,
                  onPressed: _submitPin,
                ),
                if (security.valueOrNull?.biometricUnlock ?? false) ...[
                  const SizedBox(height: AppSpacing.lg),
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint_rounded, color: Colors.white),
                    label: const Text('Use Face / Fingerprint',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                TextButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  child: Text('Log out instead',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
