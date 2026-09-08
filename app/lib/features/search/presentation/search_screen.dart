import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/clay.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../accounts/data/account_model.dart';
import '../../accounts/state/accounts_provider.dart';
import '../../transactions/data/transaction_model.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/state/history_controller.dart';

/// Screen 26 — Search & Filter
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _search = TextEditingController();
  final _minAmount = TextEditingController();
  final _maxAmount = TextEditingController();

  Timer? _debounce;
  String? _accountId;
  String? _type;
  HistoryRange _range = HistoryRange.thisMonth;

  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<TransactionItem> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _minAmount.dispose();
    _maxAmount.dispose();
    super.dispose();
  }

  /// Debounced so typing doesn't fire a request per keystroke.
  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch() async {
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });

    final (from, to) = _range.bounds;
    try {
      final page = await ref.read(transactionRepositoryProvider).list(
            TransactionQuery(
              search: _search.text.trim().isEmpty ? null : _search.text.trim(),
              accountId: _accountId,
              type: _type,
              from: from,
              to: to,
              minAmount: double.tryParse(_minAmount.text.replaceAll(',', '')),
              maxAmount: double.tryParse(_maxAmount.text.replaceAll(',', '')),
              limit: 50,
            ),
          );
      if (!mounted) return;
      setState(() {
        _results = page.items;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  void _reset() {
    setState(() {
      _search.clear();
      _minAmount.clear();
      _maxAmount.clear();
      _accountId = null;
      _type = null;
      _range = HistoryRange.thisMonth;
      _results = [];
      _searched = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull;
    final currency = accounts?.currency ?? 'PKR';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Search & Filter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
            child: TextField(
              controller: _search,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Search transactions',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20, color: context.cTextSecondary),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          _runSearch();
                        },
                      ),
              ),
            ),
          ),
          _FilterSheetButton(
            summary: _filterSummary(accounts?.accounts ?? const []),
            onTap: () => _openFilters(accounts?.accounts ?? const []),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null) {
                  return ErrorView(message: _error!, onRetry: _runSearch);
                }
                if (!_searched) {
                  return const EmptyState(
                    icon: Icons.search_rounded,
                    title: 'Search your money',
                    message:
                        'Find any transaction by note, account, type, date or amount.',
                  );
                }
                if (_results.isEmpty) {
                  return EmptyState(
                    title: 'No transactions found',
                    message: "You don't have any transactions for this period.",
                    actionLabel: 'Reset Filters',
                    onAction: _reset,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                      AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
                  itemCount: _results.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          '${_results.length} result'
                          '${_results.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    final item = _results[index - 1];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                        boxShadow: Clay.shadows(context, context.cBackground,
                            small: true),
                      ),
                      child: InkWell(
                        onTap: () => context.push('/transactions/${item.id}'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.subtitle} · ${Fmt.date(item.date)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${item.isIncome ? '+' : '-'}'
                              '${Fmt.currency(item.amount, code: currency, decimals: false)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: item.isIncome
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _filterSummary(List<Account> accounts) {
    final parts = <String>[_range.label];
    if (_type != null) parts.add(_type!);
    if (_accountId != null) {
      final match = accounts.where((a) => a.id == _accountId).firstOrNull;
      if (match != null) parts.add(match.name);
    }
    if (_minAmount.text.isNotEmpty || _maxAmount.text.isNotEmpty) {
      parts.add('amount');
    }
    return parts.join(' · ');
  }

  void _openFilters(List<Account> accounts) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              Text('Type', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final option in [null, 'expense', 'income', 'transfer'])
                    ChoiceChip(
                      label: Text(option ?? 'All'),
                      selected: _type == option,
                      showCheckmark: false,
                      onSelected: (_) => setSheetState(() => _type = option),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Date range', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: HistoryRange.values
                    .map((r) => ChoiceChip(
                          label: Text(r.label),
                          selected: _range == r,
                          showCheckmark: false,
                          onSelected: (_) => setSheetState(() => _range = r),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minAmount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Min amount'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _maxAmount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Max amount'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _reset();
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Apply Filter',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        setState(() {});
                        _runSearch();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheetButton extends StatelessWidget {
  const _FilterSheetButton({required this.summary, required this.onTap});
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, size: 17, color: AppColors.forest),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: context.cTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
