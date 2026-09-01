import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/settings_tile.dart';
import '../../auth/state/auth_controller.dart';
import '../data/settings_repository.dart';

/// Screen 22 — Profile
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.forest.withOpacity(0.10),
                child: Text(
                  Fmt.initials(user?.fullName ?? user?.email ?? '?'),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.fullName ?? 'Your name',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall),
                    if ((user?.phone ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(user!.phone,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          SettingsGroup(
            title: 'Account',
            children: [
              SettingsTile(
                title: 'Personal Information',
                icon: Icons.person_outline_rounded,
                iconColor: AppColors.forest,
                onTap: () => _showEditSheet(context, ref),
              ),
              SettingsTile(
                title: 'Preferences',
                icon: Icons.tune_rounded,
                iconColor: const Color(0xFFA855F7),
                onTap: () => context.push('/settings'),
              ),
              SettingsTile(
                title: 'Security',
                icon: Icons.shield_outlined,
                iconColor: AppColors.expense,
                onTap: () => context.push('/security'),
              ),
              SettingsTile(
                title: 'Backup & Restore',
                icon: Icons.cloud_outlined,
                iconColor: const Color(0xFF6366F1),
                showDivider: false,
                onTap: () => context.push('/backup'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          SettingsGroup(
            title: 'Support',
            children: [
              SettingsTile(
                title: 'Help & Support',
                icon: Icons.help_outline_rounded,
                iconColor: const Color(0xFF8B5CF6),
                onTap: () => context.push('/help'),
              ),
              SettingsTile(
                title: 'About HISAB',
                subtitle: 'Version 1.0.0',
                icon: Icons.info_outline_rounded,
                showDivider: false,
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
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
            ),
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
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _EditProfileSheet(),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _fullName = TextEditingController(text: user?.fullName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).updateProfile({
        'fullName': _fullName.text.trim(),
        'phone': _phone.text.trim(),
      });
      // Pull the fresh user through the auth controller so every screen updates.
      await ref.read(authControllerProvider.notifier).restoreSession();
      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, 'Profile updated');
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
            Text('Personal Information',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Full Name',
              controller: _fullName,
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'Full name'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Phone',
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
                label: 'Save Changes', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
