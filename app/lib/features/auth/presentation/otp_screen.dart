import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/otp_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../state/auth_controller.dart';

/// Screen 4 — OTP Verification
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _resendWindow = 60;

  String _code = '';
  bool _hasError = false;
  int _secondsLeft = _resendWindow;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendWindow);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onDigit(String d) {
    if (_code.length >= 6) return;
    setState(() {
      _code += d;
      _hasError = false;
    });
    if (_code.length == 6) _verify();
  }

  void _onBackspace() {
    if (_code.isEmpty) return;
    setState(() {
      _code = _code.substring(0, _code.length - 1);
      _hasError = false;
    });
  }

  Future<void> _verify() async {
    final ok = await ref.read(authControllerProvider.notifier).verifyOtp(_code);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _hasError = true;
        _code = '';
      });
      showAppSnack(context,
          ref.read(authControllerProvider).error ?? 'Verification failed',
          isError: true);
    }
  }

  Future<void> _resend() async {
    final devCode = await ref.read(authControllerProvider.notifier).resendOtp();
    if (!mounted) return;
    _startTimer();
    showAppSnack(
        context,
        devCode != null
            ? 'Code sent (dev: $devCode)'
            : 'Verification code sent');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final destination = auth.user?.phone.isNotEmpty == true
        ? auth.user!.phone
        : auth.user?.email ?? 'your device';

    return Scaffold(
      backgroundColor: context.cSurface,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        foregroundColor: context.cTextPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : ref.read(authControllerProvider.notifier).logout(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verify OTP', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text('Enter 6 digit code sent to\n$destination',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xxxl),
              OtpBoxes(code: _code, hasError: _hasError),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: _secondsLeft > 0
                    ? Text('Resend code in ${Fmt.countdown(_secondsLeft)}',
                        style: theme.textTheme.bodySmall)
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('Resend code',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
              ),
              if (auth.devOtpCode != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.incomeSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Dev code: ${auth.devOtpCode}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.forest,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
              const Spacer(),
              if (auth.loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                )
              else
                PrimaryButton(
                  label: 'Verify',
                  onPressed: _code.length == 6 ? _verify : null,
                ),
              const SizedBox(height: AppSpacing.lg),
              NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
