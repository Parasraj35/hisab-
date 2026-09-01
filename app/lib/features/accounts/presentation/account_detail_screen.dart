import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_map.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/transaction_tile.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../data/account_model.dart';
import '../data/account_repository.dart';
import '../state/accounts_provider.dart';
import 'accounts_screen.dart' show showAccountSheet;

final _accountTransactionsProvider =
    FutureProvider.family<TransactionPage, String>(
  (ref, accountId) => ref
      .read(transactionRepositoryProvider)
      .list(TransactionQuery(accountId: accountId, limit: 15)),
);

/// Account Detail — reached by tapping an account row on the Dashboard.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/accounts'),
        ),
        title: const Text('Account Detail'),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(accountsProvider),
        ),
        data: (payload) {
          final matches = payload.accounts.where((a) => a.id == id);
          if (matches.isEmpty) {
            return const ErrorView(message: 'This account no longer exists.');
          }
          return _Body(account: matches.first);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(account.color, fallback: context.cPrimary);
    final txAsync = ref.watch(_accountTransactionsProvider(account.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(accountsProvider);
        ref.invalidate(_accountTransactionsProvider(account.id));
        await ref.read(accountsProvider.future);
      },
      color: context.cPrimary,
      child: ListView(
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
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(iconForAccountType(account.type),
                      size: 30, color: color),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(account.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  Fmt.currency(account.currentBalance, code: account.currency),
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(account.type.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color)),
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
              border: Border.all(color: context.cBorder),
            ),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Type',
                  value: account.type[0].toUpperCase() +
                      account.type.substring(1),
                ),
                _DetailRow(label: 'Currency', value: account.currency),
                _DetailRow(
                  label: 'Opening Balance',
                  value: Fmt.currency(account.initialBalance,
                      code: account.currency),
                ),
                _DetailRow(
                  label: 'Status',
                  value: account.isDefault
                      ? 'Default account'
                      : (account.isArchived ? 'Archived' : 'Active'),
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
                  onPressed: () =>
                      showAccountSheet(context, ref, existing: account),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context, ref, account),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.cExpense,
                    side: BorderSide(color: context.cExpense),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Recent Transactions',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          txAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => ErrorView(
              message: err.toString(),
              onRetry: () =>
                  ref.invalidate(_accountTransactionsProvider(account.id)),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return const EmptyState(
                  title: 'No transactions yet',
                  message: 'Transactions on this account will show up here.',
                );
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: context.cBorder),
                ),
                child: Column(
                  children: page.items.asMap().entries.map((entry) {
                    final item = entry.value;
                    return TransactionTile(
                      item: item,
                      currency: account.currency,
                      showDivider: entry.key < page.items.length - 1,
                      onTap: () => context.push('/transactions/${item.id}'),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Account account) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
            'If ${account.name} has transactions it will be archived instead, '
            'so your history and reports stay accurate.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final archived =
                    await ref.read(accountRepositoryProvider).remove(account.id);
                ref.invalidate(accountsProvider);
                ref.invalidate(dashboardOverviewProvider);
                if (context.mounted) {
                  showAppSnack(context,
                      archived ? '${account.name} archived' : '${account.name} deleted');
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) showAppSnack(context, e.toString(), isError: true);
              }
            },
            child:
                Text('Delete', style: TextStyle(color: dialogContext.cExpense)),
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
                width: 110,
                child: Text(label, style: Theme.of(context).textTheme.bodySmall),
              ),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge!
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
