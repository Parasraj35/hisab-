import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../accounts/state/accounts_provider.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/settings_repository.dart';

/// Screen 20 — Backup / Restore
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).createBackup();
      ref.invalidate(backupsProvider);
      if (mounted) showAppSnack(context, 'Backup created');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRestore(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'Your current data will be replaced with the snapshot from '
          '${Fmt.date(backup.createdAt)}.\n\n'
          'A safety backup of your current data is taken first, so this can be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).restoreBackup(backup.id);
      // Everything downstream is now stale.
      ref.invalidate(backupsProvider);
      ref.invalidate(dashboardOverviewProvider);
      ref.invalidate(accountsProvider);
      if (mounted) showAppSnack(context, 'Backup restored');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(backupsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: const Text('Backup & Restore'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(backupsProvider),
        ),
        data: (backups) {
          final latest = backups.isNotEmpty ? backups.first : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cloud_done_outlined,
                              size: 20, color: AppColors.forest),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Last Backup',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 2),
                              Text(
                                latest == null
                                    ? 'No backups yet'
                                    : '${Fmt.date(latest.createdAt)} · ${Fmt.time(latest.createdAt)}',
                                style: Theme.of(context).textTheme.titleMedium!
                                    .copyWith(fontSize: 14),
                              ),
                              if (latest != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Size ${latest.sizeLabel} · '
                                  '${latest.transactionCount} transactions',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              PrimaryButton(
                label: 'Create Backup',
                icon: Icons.backup_outlined,
                loading: _busy,
                onPressed: _createBackup,
              ),
              const SizedBox(height: AppSpacing.xxl),

              Text('Available Backups',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),

              if (backups.isEmpty)
                AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text('Nothing backed up yet',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: backups.asMap().entries.map((entry) {
                      final backup = entry.value;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${Fmt.date(backup.createdAt)} · '
                                        '${Fmt.time(backup.createdAt)}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${backup.sizeLabel} · '
                                        '${backup.transactionCount} transactions',
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      _busy ? null : () => _confirmRestore(backup),
                                  child: const Text('Restore',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await ref
                                        .read(settingsRepositoryProvider)
                                        .deleteBackup(backup.id);
                                    ref.invalidate(backupsProvider);
                                  },
                                  icon: Icon(Icons.delete_outline_rounded,
                                      size: 18, color: context.cTextTertiary),
                                ),
                              ],
                            ),
                          ),
                          if (entry.key < backups.length - 1)
                            Divider(height: 1, color: context.cDivider),
                        ],
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                'HISAB keeps your 10 most recent backups. Restoring replaces your '
                'current data, but a safety snapshot is taken first.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
