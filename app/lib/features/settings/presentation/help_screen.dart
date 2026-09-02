import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/clay.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/settings_tile.dart';

/// Screen 25 — Help / Support
class HelpScreen extends StatelessWidget {
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
      'How do backups work?',
      'A backup snapshots your accounts, categories, transactions, debts and goals. '
          'HISAB keeps your 10 most recent. Restoring takes a safety snapshot first, '
          'so it can be undone.'
    ),
    (
      'Is my data private?',
      'Your data is tied to your account and never shared. Passwords and PINs are '
          'hashed, and you can add app lock or biometric unlock under Security.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
                        color: Colors.white.withOpacity(0.7), fontSize: 12)),
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
              boxShadow: Clay.shadows(context.cBackground, small: true),
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
                icon: Icons.mail_outline_rounded,
                iconColor: const Color(0xFF3B82F6),
                onTap: () =>
                    showAppSnack(context, 'Email support@hisab.app for help'),
              ),
              SettingsTile(
                title: 'Report a Problem',
                icon: Icons.bug_report_outlined,
                iconColor: AppColors.expense,
                onTap: () => showAppSnack(
                    context, 'Thanks — describe the issue in an email'),
              ),
              SettingsTile(
                title: 'Suggest a Feature',
                icon: Icons.lightbulb_outline_rounded,
                iconColor: AppColors.warning,
                onTap: () => showAppSnack(context, 'We would love to hear it'),
              ),
              SettingsTile(
                title: 'Rate HISAB',
                icon: Icons.star_outline_rounded,
                iconColor: const Color(0xFFEAB308),
                showDivider: false,
                onTap: () =>
                    showAppSnack(context, 'Opens your app store listing'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Text('HISAB v1.0.0',
                style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}
