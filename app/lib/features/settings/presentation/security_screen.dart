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
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/settings_tile.dart';
import '../../auth/state/auth_controller.dart';
import '../data/settings_repository.dart';

/// Screen 21 — Security
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(securityProvider);
    final repo = ref.read(settingsRepositoryProvider);

    Future<void> patch(Map<String, dynamic> changes) async {
      try {
        await repo.updateSettings(changes);
        ref.invalidate(securityProvider);
      } catch (e) {
        if (context.mounted) showAppSnack(context, e.toString(), isError: true);
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: const Text('Security'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(securityProvider),
        ),
        data: (status) => ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
          children: [
            SettingsGroup(
              title: 'App Lock',
              children: [
                SettingsTile(
                  title: 'App Lock',
                  subtitle: status.hasPin
                      ? 'Use PIN or biometric to unlock the app'
                      : 'Set a PIN first to enable this',
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppColors.expense,
                  trailing: Switch(
                    value: status.appLock,
                    // Without a PIN there's nothing to unlock with, so the
                    // switch stays inert until one is set.
                    onChanged:
                        status.hasPin ? (v) => patch({'appLock': v}) : null,
                  ),
                ),
                SettingsTile(
                  title: status.hasPin ? 'Change PIN' : 'Set PIN',
                  icon: Icons.pin_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  onTap: () =>
                      _showPinSheet(context, ref, hasPin: status.hasPin),
                ),
                SettingsTile(
                  title: 'Biometric Unlock',
                  subtitle: 'Fingerprint or face unlock',
                  icon: Icons.fingerprint_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  trailing: Switch(
                    value: status.biometricUnlock,
                    onChanged: status.hasPin
                        ? (v) async {
                            if (v) {
                              final available = await _checkBiometrics(context);
                              if (!available) return;
                            }
                            await patch({'biometricUnlock': v});
                          }
                        : null,
                  ),
                ),
                SettingsTile(
                  title: 'Auto Lock',
                  subtitle: status.autoLockMinutes == 0
                      ? 'Immediately'
                      : 'After ${status.autoLockMinutes} minute'
                          '${status.autoLockMinutes == 1 ? '' : 's'}',
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.warning,
                  showDivider: false,
                  onTap: () => _showAutoLockSheet(
                      context, patch, status.autoLockMinutes),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SettingsGroup(
              title: 'Account',
              children: [
                SettingsTile(
                  title: 'Change Password',
                  icon: Icons.key_outlined,
                  iconColor: AppColors.forest,
                  showDivider: status.hasPin,
                  onTap: () => _showPasswordSheet(context, ref),
                ),
                if (status.hasPin)
                  SettingsTile(
                    title: 'Remove PIN',
                    icon: Icons.lock_open_rounded,
                    danger: true,
                    showDivider: false,
                    onTap: () async {
                      await repo.removePin();
                      ref.invalidate(securityProvider);
                      if (context.mounted) showAppSnack(context, 'PIN removed');
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.expense,
                side: const BorderSide(color: AppColors.expense),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log Out',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkBiometrics(BuildContext context) async {
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      if (!supported || !canCheck) {
        if (context.mounted) {
          showAppSnack(context, 'This device has no biometrics set up',
              isError: true);
        }
        return false;
      }
      return await auth.authenticate(
        localizedReason: 'Confirm it is you to enable biometric unlock',
        options:
            const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (e) {
      if (context.mounted) showAppSnack(context, e.toString(), isError: true);
      return false;
    }
  }

  void _showAutoLockSheet(BuildContext context,
      Future<void> Function(Map<String, dynamic>) patch, int current) {
    const options = [0, 1, 5, 15, 30];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text('Auto lock after',
                style: Theme.of(context).textTheme.titleMedium),
            ...options.map((m) => ListTile(
                  title: Text(
                      m == 0 ? 'Immediately' : '$m minute${m == 1 ? '' : 's'}'),
                  trailing: m == current
                      ? const Icon(Icons.check_circle,
                          color: AppColors.accent, size: 20)
                      : null,
                  onTap: () {
                    patch({'autoLockMinutes': m});
                    Navigator.pop(sheetContext);
                  },
                )),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _showPinSheet(BuildContext context, WidgetRef ref,
      {required bool hasPin}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PinSheet(hasPin: hasPin),
    );
  }

  void _showPasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PasswordSheet(),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(authControllerProvider.notifier).logout();
            },
            child: const Text('Log out',
                style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}

class _PinSheet extends ConsumerStatefulWidget {
  const _PinSheet({required this.hasPin});
  final bool hasPin;

  @override
  ConsumerState<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<_PinSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).setPin(
            _pin.text,
            currentPin: widget.hasPin ? _current.text : null,
          );
      ref.invalidate(securityProvider);
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, 'PIN saved');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _pinValidator(String? v) {
    if (v == null || v.isEmpty) return 'PIN is required';
    if (!RegExp(r'^\d{4,6}$').hasMatch(v)) return 'Use 4 to 6 digits';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.hasPin ? 'Change PIN' : 'Set PIN',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            if (widget.hasPin) ...[
              AppTextField(
                label: 'Current PIN',
                controller: _current,
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: _pinValidator,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppTextField(
              label: 'New PIN',
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              validator: _pinValidator,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Confirm PIN',
              controller: _confirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              validator: (v) => v != _pin.text ? 'PINs do not match' : null,
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
                label: 'Save PIN', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .changePassword(_current.text, _next.text);
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, 'Password changed');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change Password',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Current Password',
              controller: _current,
              obscureText: true,
              validator: (v) => Validators.required(v, 'Current password'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'New Password',
              controller: _next,
              obscureText: true,
              validator: Validators.password,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Confirm New Password',
              controller: _confirm,
              obscureText: true,
              validator: (v) =>
                  v != _next.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
                label: 'Change Password', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
