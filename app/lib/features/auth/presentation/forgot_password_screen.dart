import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../settings/data/settings_repository.dart';
import '../data/auth_repository.dart';
import '../state/auth_controller.dart';

enum _Step { checking, verify, noRecovery, newPassword }

/// Forgotten-password recovery for a fully local, no-server app: there's no
/// email/SMS to send a code to, so identity is proven with whatever local
/// unlock method was already set up (PIN / biometric) instead — the same
/// mechanism App Lock uses, just triggered from the Login screen rather
/// than on resume. If no PIN was ever set, there's nothing to verify
/// against and the only way forward is a full local reset.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _Step _step = _Step.checking;
  bool _biometricAvailable = false;
  bool _biometricTried = false;

  final _pinFormKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  bool _obscurePin = true;
  bool _checkingPin = false;
  String? _pinError;

  final _passwordFormKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _savingPassword = false;

  bool _resettingAppData = false;

  @override
  void initState() {
    super.initState();
    _loadRecoveryOptions();
  }

  @override
  void dispose() {
    _pin.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _loadRecoveryOptions() async {
    final status = await ref.read(settingsRepositoryProvider).security();
    if (!mounted) return;
    setState(() {
      _step = status.hasPin ? _Step.verify : _Step.noRecovery;
      _biometricAvailable = status.biometricUnlock;
    });
    if (status.hasPin && status.biometricUnlock && !_biometricTried) {
      _biometricTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    if (!mounted) return;
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      if (!supported || !canCheck) return;

      final ok = await auth.authenticate(
        localizedReason: 'Verify it\'s you to reset your password',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok && mounted) setState(() => _step = _Step.newPassword);
    } catch (_) {
      // Fall through to PIN entry.
    }
  }

  Future<void> _verifyPin() async {
    if (!_pinFormKey.currentState!.validate()) return;
    setState(() {
      _checkingPin = true;
      _pinError = null;
    });

    final correct = await ref.read(settingsRepositoryProvider).verifyPin(_pin.text.trim());
    if (!mounted) return;

    if (correct) {
      setState(() {
        _checkingPin = false;
        _step = _Step.newPassword;
      });
    } else {
      setState(() {
        _checkingPin = false;
        _pinError = 'Incorrect PIN';
      });
      _pin.clear();
    }
  }

  Future<void> _submitNewPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingPassword = true);

    try {
      await ref
          .read(profileRepositoryProvider)
          .resetPasswordWithoutOldPassword(_password.text);
      if (!mounted) return;
      showAppSnack(context, 'Password updated — please log in');
      context.go('/login');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _confirmResetAppData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Erase all data on this device?'),
        content: const Text(
          'There\'s no way to recover this password without a PIN or biometric '
          'unlock already set up. The only way to start over is to erase every '
          'account, transaction, and setting stored on this device. This '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Erase and Start Over',
                style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _resettingAppData = true);
    await ref.read(authControllerProvider.notifier).resetAppData();
    // Status flips to unauthenticated either way, but this screen itself
    // stays put unless told otherwise (it's still a "public" route) — send
    // the now-blank device to Login explicitly rather than leaving the
    // stale "no recovery" view on screen.
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.cSurface,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        foregroundColor: context.cTextPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: switch (_step) {
            _Step.checking => const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              ),
            _Step.verify => _VerifyPinView(
                theme: theme,
                formKey: _pinFormKey,
                pin: _pin,
                obscure: _obscurePin,
                onToggleObscure: () => setState(() => _obscurePin = !_obscurePin),
                error: _pinError,
                checking: _checkingPin,
                onSubmit: _verifyPin,
                biometricAvailable: _biometricAvailable,
                onTryBiometric: _tryBiometric,
              ),
            _Step.noRecovery => _NoRecoveryView(
                theme: theme,
                busy: _resettingAppData,
                onResetAppData: _confirmResetAppData,
              ),
            _Step.newPassword => _NewPasswordView(
                theme: theme,
                formKey: _passwordFormKey,
                password: _password,
                confirmPassword: _confirmPassword,
                obscurePassword: _obscurePassword,
                obscureConfirm: _obscureConfirm,
                onToggleObscurePassword: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onToggleObscureConfirm: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                saving: _savingPassword,
                onSubmit: _submitNewPassword,
              ),
          },
        ),
      ),
    );
  }
}

class _VerifyPinView extends StatelessWidget {
  const _VerifyPinView({
    required this.theme,
    required this.formKey,
    required this.pin,
    required this.obscure,
    required this.onToggleObscure,
    required this.error,
    required this.checking,
    required this.onSubmit,
    required this.biometricAvailable,
    required this.onTryBiometric,
  });

  final ThemeData theme;
  final GlobalKey<FormState> formKey;
  final TextEditingController pin;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final String? error;
  final bool checking;
  final VoidCallback onSubmit;
  final bool biometricAvailable;
  final VoidCallback onTryBiometric;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verify It\'s You', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter your PIN to reset your password.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          AppTextField(
            label: 'PIN',
            controller: pin,
            obscureText: obscure,
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.isEmpty) ? 'PIN is required' : null,
            suffix: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: context.cTextSecondary,
              ),
              onPressed: onToggleObscure,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(error!, style: const TextStyle(color: AppColors.expense, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(label: 'Verify', loading: checking, onPressed: onSubmit),
          if (biometricAvailable) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: TextButton.icon(
                onPressed: onTryBiometric,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Use Face / Fingerprint'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoRecoveryView extends StatelessWidget {
  const _NoRecoveryView({
    required this.theme,
    required this.busy,
    required this.onResetAppData,
  });

  final ThemeData theme;
  final bool busy;
  final VoidCallback onResetAppData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Icon(Icons.lock_reset_rounded, size: 48, color: context.cTextTertiary),
        const SizedBox(height: AppSpacing.lg),
        Text('No Recovery Method Set Up', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This device never had a PIN or biometric unlock set up, so there\'s '
          'no way to verify it\'s you without your password. Since everything '
          'is stored only on this device, the only way to continue is to '
          'erase it and start over.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(
          label: 'Erase and Start Over',
          loading: busy,
          onPressed: onResetAppData,
        ),
      ],
    );
  }
}

class _NewPasswordView extends StatelessWidget {
  const _NewPasswordView({
    required this.theme,
    required this.formKey,
    required this.password,
    required this.confirmPassword,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onToggleObscurePassword,
    required this.onToggleObscureConfirm,
    required this.saving,
    required this.onSubmit,
  });

  final ThemeData theme;
  final GlobalKey<FormState> formKey;
  final TextEditingController password;
  final TextEditingController confirmPassword;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onToggleObscureConfirm;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set a New Password', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('Verified — choose a new password for this device.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xxxl),
          AppTextField(
            label: 'New Password',
            controller: password,
            hint: 'At least 8 characters',
            obscureText: obscurePassword,
            validator: Validators.password,
            suffix: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: context.cTextSecondary,
              ),
              onPressed: onToggleObscurePassword,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'Confirm Password',
            controller: confirmPassword,
            hint: 'Re-enter your password',
            obscureText: obscureConfirm,
            validator: Validators.confirmPassword(password),
            suffix: IconButton(
              icon: Icon(
                obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: context.cTextSecondary,
              ),
              onPressed: onToggleObscureConfirm,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
              label: 'Save New Password', loading: saving, onPressed: onSubmit),
        ],
      ),
    );
  }
}
