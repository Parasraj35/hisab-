import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/clay.dart';
import '../../../core/utils/app_version.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/settings_tile.dart';

/// Screen 25 — Help / Support
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'How are my account balances calculated?',
      'Each balance is your opening balance plus all income and incoming transfers, '
          'minus all expenses and outgoing transfers. Editing or deleting a transaction '
          'recalculates it immediately, so the number can never drift.'
    ),
    (
      'Why is my transfer not in my reports?',
      'Transfers move money between your own accounts, so they are not income or '
          'expense. Counting them would inflate both sides of your report.'
    ),
    (
      'What happens when I delete an account with transactions?',
      'It is archived rather than deleted. A hard delete would orphan your '
          'transactions and break your history and reports.'
    ),
    (
      'Can I record a partial repayment?',
      'Yes. On the Debt / Lending screen tap Record Payment and enter any amount up '
          'to what is outstanding. The record shows a progress bar until it is settled.'
    ),
    (
      'Is my data private?',
      'HISAB has no server — your accounts, transactions and profile are stored only '
          'in a local database on this device, and never uploaded anywhere. Your '
          'password and PIN are hashed, and you can add app lock or biometric unlock '
          'under Security. See the full Privacy Policy below for exactly what the '
          'ads and crash-reporting SDKs collect.'
    ),
    (
      'What happens if I uninstall or reset the app?',
      'All local data is erased — there is no cloud backup to restore from. That is '
          'a deliberate trade-off for keeping your financial data off any server, so '
          'make sure you export a report first if you want a copy of your history.'
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.forest,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent_rounded,
                    size: 38, color: Colors.white),
                const SizedBox(height: AppSpacing.md),
                const Text('How can we help you?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text("We're here to help",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Frequently Asked',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              boxShadow:
                  Clay.shadows(context, context.cBackground, small: true),
            ),
            child: Column(
              children: _faqs.asMap().entries.map((entry) {
                return Column(
                  children: [
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(entry.value.$1,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w500)),
                        iconColor: AppColors.forest,
                        childrenPadding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(entry.value.$2,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                    if (entry.key < _faqs.length - 1)
                      Divider(height: 1, color: context.cDivider),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            title: 'Get in touch',
            children: [
              SettingsTile(
                title: 'Contact Support',
                subtitle: kSupportEmail,
                icon: Icons.mail_outline_rounded,
                iconColor: const Color(0xFF3B82F6),
                onTap: () => _launchMail(context, subject: 'HISAB support'),
              ),
              SettingsTile(
                title: 'Report a Problem',
                icon: Icons.bug_report_outlined,
                iconColor: AppColors.expense,
                onTap: () => _launchMail(context, subject: 'HISAB bug report'),
              ),
              SettingsTile(
                title: 'Suggest a Feature',
                icon: Icons.lightbulb_outline_rounded,
                iconColor: AppColors.warning,
                onTap: () =>
                    _launchMail(context, subject: 'HISAB feature suggestion'),
              ),
              SettingsTile(
                title: 'Privacy Policy',
                icon: Icons.privacy_tip_outlined,
                iconColor: AppColors.forest,
                showDivider: false,
                onTap: () => _launchUrl(context, kPrivacyPolicyUrl),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Text('HISAB v${version ?? '—'}',
                style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMail(BuildContext context, {required String subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      showAppSnack(context, 'No email app found — reach us at $kSupportEmail',
          isError: true);
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnack(context, 'Could not open the link', isError: true);
    }
  }
}
