import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../accounts/data/account_model.dart';
import '../../transactions/data/transaction_model.dart';

class MonthSummary {
  const MonthSummary({
    required this.label,
    required this.income,
    required this.expense,
    required this.net,
  });

  final String label;
  final double income;
  final double expense;
  final double net;

  factory MonthSummary.fromJson(Map<String, dynamic> json) => MonthSummary(
        label: (json['label'] ?? '').toString(),
        income: (json['income'] ?? 0).toDouble(),
        expense: (json['expense'] ?? 0).toDouble(),
        net: (json['net'] ?? 0).toDouble(),
      );
}

class DashboardOverview {
  const DashboardOverview({
    required this.currency,
    required this.totalBalance,
    required this.accounts,
    required this.thisMonth,
    required this.recentTransactions,
    required this.unreadNotifications,
  });

  final String currency;
  final double totalBalance;
  final List<Account> accounts;
  final MonthSummary thisMonth;
  final List<TransactionItem> recentTransactions;
  final int unreadNotifications;

  factory DashboardOverview.fromJson(Map<String, dynamic> json) =>
      DashboardOverview(
        currency: (json['currency'] ?? 'PKR').toString(),
        totalBalance: (json['totalBalance'] ?? 0).toDouble(),
        accounts: (json['accounts'] as List? ?? [])
            .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        thisMonth: MonthSummary.fromJson(
            Map<String, dynamic>.from(json['thisMonth'] ?? {})),
        recentTransactions: (json['recentTransactions'] as List? ?? [])
            .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        unreadNotifications: (json['unreadNotifications'] ?? 0) as int,
      );
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
    (ref) => DashboardRepository(ref.read(apiClientProvider)));

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<DashboardOverview> overview() async {
    final res = await _api.get(ApiEndpoints.dashboardOverview);
    return DashboardOverview.fromJson(Map<String, dynamic>.from(res['data']));
  }
}

/// Single source of truth for the dashboard. Invalidate after any mutation
/// so balances and recent activity refresh together.
final dashboardOverviewProvider = FutureProvider<DashboardOverview>(
    (ref) => ref.read(dashboardRepositoryProvider).overview());
