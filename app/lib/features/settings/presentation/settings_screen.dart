import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/settings_tile.dart';
import '../../auth/state/auth_controller.dart';
import '../data/settings_repository.dart';

/// Screen 23 — Settings
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _currencies = ['PKR', 'USD', 'GBP', 'EUR', 'AED', 'SAR'];
  static const _themes = ['system', 'light', 'dark'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final themeMode = ref.watch(themeModeProvider);
    final repo = ref.read(settingsRepositoryProvider);

    Future<void> patch(Map<String, dynamic> changes) async {
      try {
        await repo.updateSettings(changes);
        await ref.read(authControllerProvider.notifier).restoreSession();
        if (context.mounted) showAppSnack(context, 'Saved');
      } catch (e) {
        if (context.mounted) showAppSnack(context, e.toString(), isError: true);
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Settings'),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 90),
        children: [
          SettingsGroup(
            title: 'General',
            children: [
              SettingsTile(
                title: 'Currency',
                subtitle: user?.currency ?? 'PKR',
                icon: Icons.attach_money_rounded,
                iconColor: AppColors.income,
                onTap: () => _pickOption(
                  context,
                  title: 'Currency',
                  options: _currencies,
                  current: user?.currency ?? 'PKR',
                  onPick: (v) => patch({'currency': v}),
                ),
              ),
              SettingsTile(
                title: 'Theme',
                subtitle: themeMode[0].toUpperCase() + themeMode.substring(1),
                icon: Icons.dark_mode_outlined,
                iconColor: const Color(0xFFA855F7),
                showDivider: false,
                onTap: () => _pickOption(
                  context,
                  title: 'Theme',
                  options: _themes,
                  current: themeMode,
                  labelBuilder: (v) => v[0].toUpperCase() + v.substring(1),
                  onPick: (v) {
                    // Applied locally first so the change is instant, then persisted.
                    ref.read(themeModeProvider.notifier).state = v;
                    patch({'theme': v});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            title: 'Management',
            children: [
              SettingsTile(
                title: 'Category Management',
                icon: Icons.category_outlined,
                iconColor: const Color(0xFFF97316),
                onTap: () => context.push('/categories'),
              ),
              SettingsTile(
                title: 'Accounts',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF14B8A6),
                onTap: () => context.go('/accounts'),
              ),
              SettingsTile(
                title: 'Debt / Lending',
                icon: Icons.handshake_outlined,
                iconColor: const Color(0xFFEC4899),
                onTap: () => context.push('/debts'),
              ),
              SettingsTile(
                title: 'Savings Goals',
                icon: Icons.savings_outlined,
                iconColor: const Color(0xFFEAB308),
                showDivider: false,
                onTap: () => context.push('/savings'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            title: 'Data & Privacy',
            children: [
              SettingsTile(
                title: 'Notifications',
                icon: Icons.notifications_none_rounded,
                iconColor: AppColors.warning,
                onTap: () => context.push('/notifications'),
              ),
              SettingsTile(
                title: 'Backup & Restore',
                icon: Icons.cloud_outlined,
                iconColor: const Color(0xFF6366F1),
                onTap: () => context.push('/backup'),
              ),
              SettingsTile(
                title: 'Export Report',
                icon: Icons.ios_share_rounded,
                iconColor: AppColors.accent,
                onTap: () => context.push('/export'),
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
            title: 'Account',
            children: [
              SettingsTile(
                title: 'Profile',
                icon: Icons.person_outline_rounded,
                iconColor: AppColors.forest,
                onTap: () => context.push('/profile'),
              ),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _pickOption(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String current,
    required void Function(String) onPick,
    String Function(String)? labelBuilder,
  }) {
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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...options.map((option) => ListTile(
                  title: Text(labelBuilder?.call(option) ?? option),
                  trailing: option == current
                      ? const Icon(Icons.check_circle,
                          color: AppColors.accent, size: 20)
                      : null,
                  onTap: () {
                    onPick(option);
                    Navigator.pop(sheetContext);
                  },
                )),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
