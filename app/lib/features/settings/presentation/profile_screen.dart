import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/local_files.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/settings_tile.dart';
import '../../auth/state/auth_controller.dart';

/// Screen 22 — Profile
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 720, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final user = ref.read(authControllerProvider).user;
      final avatarPath = await saveAvatarFile(picked.path);
      final ok = await ref.read(authControllerProvider.notifier).saveProfile(
            fullName: user?.fullName ?? '',
            email: user?.email,
            phone: user?.phone,
            avatarUrl: avatarPath,
          );
      if (mounted && ok) showAppSnack(context, 'Photo updated');
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Could not upload photo: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final hasPhoto = user?.avatarUrl.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.forest.withValues(alpha: 0.10),
                    backgroundImage: hasPhoto
                        ? FileImage(File(user!.avatarUrl)) as ImageProvider
                        : null,
                    child: hasPhoto
                        ? null
                        : Text(
                            Fmt.initials(user?.fullName ?? user?.email ?? '?'),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest),
                          ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: InkWell(
                      onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.cSurface, width: 2),
                        ),
                        child: _uploadingAvatar
                            ? const SizedBox(
                                height: 12,
                                width: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt_rounded,
                                size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
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
                title: 'Security',
                icon: Icons.shield_outlined,
                iconColor: AppColors.expense,
                showDivider: false,
                onTap: () => context.push('/security'),
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
              const SettingsTile(
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
      final user = ref.read(authControllerProvider).user;
      final ok = await ref.read(authControllerProvider.notifier).saveProfile(
            fullName: _fullName.text.trim(),
            email: user?.email,
            phone: _phone.text.trim(),
            avatarUrl: user?.avatarUrl,
          );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        showAppSnack(context, 'Profile updated');
      } else {
        showAppSnack(
            context, ref.read(authControllerProvider).error ?? 'Could not save',
            isError: true);
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
