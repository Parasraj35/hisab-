import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/clay.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_map.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../accounts/state/accounts_provider.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/transaction_model.dart';
import '../data/transaction_repository.dart';
import '../state/history_controller.dart';

final transactionDetailProvider =
    FutureProvider.family<TransactionItem, String>(
        (ref, id) => ref.read(transactionRepositoryProvider).getOne(id));

/// Screen 14 — Transaction Detail
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Transaction Detail'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(transactionDetailProvider(id)),
        ),
        data: (item) => _Body(item: item),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item});
  final TransactionItem item;

  Color get _accent => item.isTransfer
      ? AppColors.info
      : item.isIncome
          ? AppColors.income
          : AppColors.expense;

  String get _typeLabel => item.isTransfer
      ? 'Transfer'
      : item.isIncome
          ? 'Income'
          : 'Expense';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = item.account?.currency ?? 'PKR';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxxl),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                height: 66,
                width: 66,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  item.isTransfer
                      ? Icons.swap_horiz_rounded
                      : iconFromSlug(item.category?.icon),
                  size: 30,
                  color: colorFromHex(item.category?.color, fallback: _accent),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(item.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${item.isIncome ? '+' : '-'}${Fmt.currency(item.amount, code: currency)}',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: _accent),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(_typeLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _accent)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: Clay.shadows(context, context.cBackground, small: true),
          ),
          child: Column(
            children: [
              _DetailRow(label: 'Date', value: Fmt.date(item.date)),
              _DetailRow(label: 'Time', value: Fmt.time(item.date)),
              if (item.isTransfer) ...[
                _DetailRow(label: 'From', value: item.account?.name ?? '—'),
                _DetailRow(label: 'To', value: item.toAccount?.name ?? '—'),
              ] else ...[
                _DetailRow(
                    label: 'Category', value: item.category?.name ?? '—'),
                _DetailRow(label: 'Account', value: item.account?.name ?? '—'),
              ],
              _DetailRow(
                label: 'Notes',
                value: item.note.isEmpty ? '—' : item.note,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context
                    .push('/transactions/${item.id}/edit')
                    .then((_) =>
                        ref.invalidate(transactionDetailProvider(item.id))),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.expense,
                  side: const BorderSide(color: AppColors.expense),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
            'This removes it permanently and updates your account balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(transactionRepositoryProvider).remove(item.id);

                // Balance, dashboard and history all shift together.
                ref.invalidate(dashboardOverviewProvider);
                ref.invalidate(accountsProvider);
                ref.read(historyControllerProvider.notifier).refresh();

                if (context.mounted) {
                  showAppSnack(context, 'Transaction deleted');
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  showAppSnack(context, e.toString(), isError: true);
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child:
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
              ),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: context.cDivider),
      ],
    );
  }
}
