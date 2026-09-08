import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/transaction_model.dart';
import '../data/transaction_repository.dart';

enum HistoryRange { thisMonth, lastMonth, last90, thisYear, all }

extension HistoryRangeX on HistoryRange {
  String get label => switch (this) {
        HistoryRange.thisMonth => 'This Month',
        HistoryRange.lastMonth => 'Last Month',
        HistoryRange.last90 => 'Last 90 Days',
        HistoryRange.thisYear => 'This Year',
        HistoryRange.all => 'All Time',
      };

  /// Null bounds mean "no constraint", which the API treats as unbounded.
  (DateTime?, DateTime?) get bounds {
    final now = DateTime.now();
    return switch (this) {
      HistoryRange.thisMonth => (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        ),
      HistoryRange.lastMonth => (
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 0, 23, 59, 59),
        ),
      HistoryRange.last90 => (now.subtract(const Duration(days: 90)), now),
      HistoryRange.thisYear => (DateTime(now.year, 1, 1), now),
      HistoryRange.all => (null, null),
    };
  }
}

class HistoryFilter {
  const HistoryFilter({
    this.accountId,
    this.type,
    this.range = HistoryRange.thisMonth,
    this.search,
  });

  final String? accountId;
  final String? type; // null = all
  final HistoryRange range;
  final String? search;

  HistoryFilter copyWith({
    Object? accountId = _unset,
    Object? type = _unset,
    HistoryRange? range,
    Object? search = _unset,
  }) =>
      HistoryFilter(
        accountId: accountId == _unset ? this.accountId : accountId as String?,
        type: type == _unset ? this.type : type as String?,
        range: range ?? this.range,
        search: search == _unset ? this.search : search as String?,
      );

  static const _unset = Object();
}

class HistoryState {
  const HistoryState({
    this.items = const [],
    this.filter = const HistoryFilter(),
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
  });

  final List<TransactionItem> items;
  final HistoryFilter filter;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;
  bool get isEmpty => !loading && error == null && items.isEmpty;

  /// Running totals for the visible range, used by the summary chips.
  double get incomeTotal =>
      items.where((i) => i.isIncome).fold(0.0, (sum, i) => sum + i.amount);
  double get expenseTotal =>
      items.where((i) => i.isExpense).fold(0.0, (sum, i) => sum + i.amount);

  HistoryState copyWith({
    List<TransactionItem>? items,
    HistoryFilter? filter,
    bool? loading,
    bool? loadingMore,
    Object? error = _unset,
    int? page,
    int? totalPages,
    int? total,
  }) =>
      HistoryState(
        items: items ?? this.items,
        filter: filter ?? this.filter,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _unset ? this.error : error as String?,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        total: total ?? this.total,
      );

  static const _unset = Object();
}

final historyControllerProvider =
    StateNotifierProvider<HistoryController, HistoryState>((ref) =>
        HistoryController(ref.read(transactionRepositoryProvider))..load());

class HistoryController extends StateNotifier<HistoryState> {
  HistoryController(this._repo) : super(const HistoryState());

  final TransactionRepository _repo;

  TransactionQuery _queryFor(HistoryFilter filter, int page) {
    final (from, to) = filter.range.bounds;
    return TransactionQuery(
      type: filter.type,
      accountId: filter.accountId,
      from: from,
      to: to,
      search: filter.search,
      page: page,
      limit: 20,
    );
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.list(_queryFor(state.filter, 1));
      state = state.copyWith(
        items: result.items,
        loading: false,
        page: result.page,
        totalPages: result.totalPages,
        total: result.total,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Appends the next page. Guarded so a fast scroll can't fire twice.
  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await _repo.list(_queryFor(state.filter, state.page + 1));
      state = state.copyWith(
        items: [...state.items, ...result.items],
        loadingMore: false,
        page: result.page,
        totalPages: result.totalPages,
        total: result.total,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }

  void applyFilter(HistoryFilter filter) {
    state = state.copyWith(filter: filter, items: [], page: 1);
    load();
  }

  Future<void> refresh() => load();
}
