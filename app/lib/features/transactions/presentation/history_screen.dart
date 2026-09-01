import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/summary_chip.dart';
import '../../../shared/widgets/transaction_tile.dart';
import '../../accounts/data/account_model.dart';
import '../../accounts/state/accounts_provider.dart';
import '../data/transaction_model.dart';
import '../state/history_controller.dart';

/// Screen 13 — History
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Prefetch one screen ahead so the list never visibly stalls.
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(historyControllerProvider.notifier).loadMore();
    }
  }

  /// Groups a flat, date-sorted list into day sections.
  List<(DateTime, List<TransactionItem>)> _groupByDay(List<TransactionItem> items) {
    final groups = <(DateTime, List<TransactionItem>)>[];
    for (final item in items) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      if (groups.isNotEmpty && groups.last.$1 == day) {
        groups.last.$2.add(item);
      } else {
        groups.add((day, [item]));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final accounts = ref.watch(accountsProvider).valueOrNull;
    final currency = accounts?.currency ?? 'PKR';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: Column(
        children: [
          _FilterBar(
            filter: state.filter,
            accounts: accounts?.accounts ?? const <Account>[],
            onChanged: controller.applyFilter,
          ),

          if (state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: SummaryChip(
                      label: 'Income',
                      amount: state.incomeTotal,
                      currency: currency,
                      isIncome: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SummaryChip(
                      label: 'Expense',
                      amount: state.expenseTotal,
                      currency: currency,
                      isIncome: false,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: Builder(
              builder: (context) {
                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.error != null && state.items.isEmpty) {
                  return ErrorView(
                      message: state.error!, onRetry: controller.refresh);
                }
                if (state.isEmpty) {
                  return EmptyState(
                    title: 'No transactions found',
                    message:
                        "You don't have any transactions for this period.",
                    actionLabel: 'Add Transaction',
                    onAction: () => context.push('/add-expense'),
                  );
                }

                final groups = _groupByDay(state.items);

                return RefreshIndicator(
                  onRefresh: controller.refresh,
                  color: AppColors.forest,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl, 0, AppSpacing.xl, 90),
                    itemCount: groups.length + 1,
                    itemBuilder: (context, index) {
                      if (index == groups.length) {
                        if (state.loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                            child: Center(
                              child: SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2)),
                            ),
                          );
                        }
                        if (!state.hasMore) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xl),
                            child: Center(
                              child: Text(
                                '${state.total} transaction'
                                '${state.total == 1 ? '' : 's'} in this period',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          );
                        }
                        return const SizedBox(height: AppSpacing.xl);
                      }

                      final (day, items) = groups[index];
                      final dayNet = items.fold<double>(
                          0, (sum, i) => sum + i.signedAmount);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                top: AppSpacing.lg, bottom: AppSpacing.xs),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(Fmt.dayHeader(day),
                                    style: Theme.of(context).textTheme.bodySmall!
                                        .copyWith(fontWeight: FontWeight.w600)),
                                Text(
                                  Fmt.signed(dayNet),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: dayNet >= 0
                                        ? AppColors.income
                                        : AppColors.expense,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.cardRadius),
                              border: Border.all(color: context.cBorder),
                            ),
                            child: Column(
                              children: items.asMap().entries.map((entry) {
                                return TransactionTile(
                                  item: entry.value,
                                  currency: currency,
                                  showDivider: entry.key < items.length - 1,
                                  onTap: () => context
                                      .push('/transactions/${entry.value.id}'),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.accounts,
    required this.onChanged,
  });

  final HistoryFilter filter;
  final List<Account> accounts;
  final ValueChanged<HistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedAccount = filter.accountId == null
        ? null
        : accounts.where((a) => a.id == filter.accountId).firstOrNull;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FilterPill(
                  label: selectedAccount?.name ?? 'All Accounts',
                  onTap: () => _pickAccount(context),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _FilterPill(
                  label: filter.range.label,
                  onTap: () => _pickRange(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _TypeChip(
                label: 'All',
                selected: filter.type == null,
                onTap: () => onChanged(filter.copyWith(type: null)),
              ),
              const SizedBox(width: AppSpacing.sm),
              _TypeChip(
                label: 'Income',
                selected: filter.type == 'income',
                color: AppColors.income,
                onTap: () => onChanged(filter.copyWith(type: 'income')),
              ),
              const SizedBox(width: AppSpacing.sm),
              _TypeChip(
                label: 'Expense',
                selected: filter.type == 'expense',
                color: AppColors.expense,
                onTap: () => onChanged(filter.copyWith(type: 'expense')),
              ),
              const SizedBox(width: AppSpacing.sm),
              _TypeChip(
                label: 'Transfer',
                selected: filter.type == 'transfer',
                color: AppColors.info,
                onTap: () => onChanged(filter.copyWith(type: 'transfer')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _pickAccount(BuildContext context) {
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
            Text('Filter by account',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              title: const Text('All Accounts'),
              trailing: filter.accountId == null
                  ? const Icon(Icons.check_circle,
                      color: AppColors.accent, size: 20)
                  : null,
              onTap: () {
                onChanged(filter.copyWith(accountId: null));
                Navigator.pop(sheetContext);
              },
            ),
            ...accounts.map((a) => ListTile(
                  title: Text(a.name),
                  trailing: filter.accountId == a.id
                      ? const Icon(Icons.check_circle,
                          color: AppColors.accent, size: 20)
                      : null,
                  onTap: () {
                    onChanged(filter.copyWith(accountId: a.id));
                    Navigator.pop(sheetContext);
                  },
                )),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _pickRange(BuildContext context) {
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
            Text('Date range', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...HistoryRange.values.map((r) => ListTile(
                  title: Text(r.label),
                  trailing: filter.range == r
                      ? const Icon(Icons.check_circle,
                          color: AppColors.accent, size: 20)
                      : null,
                  onTap: () {
                    onChanged(filter.copyWith(range: r));
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: context.cTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.forest,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : context.cBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? color : context.cTextSecondary)),
      ),
    );
  }
}
