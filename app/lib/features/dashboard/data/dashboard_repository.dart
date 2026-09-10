import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/local_db/app_database.dart';
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
}

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DashboardRepository());

/// A direct port of dashboard.controller.js's overview() — one call that
/// covers everything the home screen renders, now built from local queries
/// instead of one aggregated network round-trip.
class DashboardRepository {
  Future<DashboardOverview> overview() async {
    final db = await AppDatabase.instance.database;

    final profileRows = await db.query('profile', limit: 1);
    final currency =
        profileRows.isEmpty ? 'PKR' : (profileRows.first['currency'] as String? ?? 'PKR');

    final accountRows = await db.query('accounts',
        where: 'is_archived = 0', orderBy: 'is_default DESC, created_at ASC');
    final accounts = accountRows
        .map((r) => Account.fromJson({
              '_id': r['id'],
              'name': r['name'],
              'type': r['type'],
              'icon': r['icon'],
              'color': r['color'],
              'currency': r['currency'],
              'initialBalance': r['initial_balance'],
              'currentBalance': r['current_balance'],
              'isDefault': r['is_default'] == 1,
              'isArchived': r['is_archived'] == 1,
            }))
        .toList();
    final totalBalance = accounts.fold(0.0, (sum, a) => sum + a.currentBalance);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
    final monthEnd =
        DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

    final monthRows = await db.rawQuery('''
      SELECT type, COALESCE(SUM(amount), 0) as total FROM transactions
      WHERE date >= ? AND date <= ? AND type IN ('expense', 'income')
      GROUP BY type
    ''', [monthStart, monthEnd]);
    double income = 0, expense = 0;
    for (final r in monthRows) {
      if (r['type'] == 'income') income = (r['total'] as num).toDouble();
      if (r['type'] == 'expense') expense = (r['total'] as num).toDouble();
    }

    final recentRows = await db.rawQuery(
        'SELECT * FROM transactions ORDER BY date DESC, created_at DESC LIMIT 5');
    final recentTransactions = await _hydrateTransactions(db, recentRows);

    final unreadRows = await db
        .rawQuery("SELECT COUNT(*) as c FROM notifications WHERE is_read = 0");
    final unreadCount = (unreadRows.first['c'] as int?) ?? 0;

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return DashboardOverview(
      currency: currency,
      totalBalance: totalBalance,
      accounts: accounts,
      thisMonth: MonthSummary(
        label: '${monthNames[now.month - 1]} ${now.year}',
        income: income,
        expense: expense,
        net: income - expense,
      ),
      recentTransactions: recentTransactions,
      unreadNotifications: unreadCount,
    );
  }

  Future<List<TransactionItem>> _hydrateTransactions(
      Database db, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final accountIds = <String>{};
    final categoryIds = <String>{};
    for (final r in rows) {
      if (r['account_id'] != null) accountIds.add(r['account_id'] as String);
      if (r['to_account_id'] != null) accountIds.add(r['to_account_id'] as String);
      if (r['category_id'] != null) categoryIds.add(r['category_id'] as String);
    }
    final accounts = await _byId(db, 'accounts', accountIds);
    final categories = await _byId(db, 'categories', categoryIds);

    return rows.map((r) {
      final account = accounts[r['account_id']];
      final toAccount = accounts[r['to_account_id']];
      final category = categories[r['category_id']];
      return TransactionItem.fromJson({
        '_id': r['id'],
        'type': r['type'],
        'amount': r['amount'],
        'date': r['date'],
        'note': r['note'],
        'account': account == null
            ? null
            : {
                '_id': account['id'],
                'name': account['name'],
                'type': account['type'],
                'icon': account['icon'],
                'color': account['color'],
              },
        'toAccount': toAccount == null
            ? null
            : {'_id': toAccount['id'], 'name': toAccount['name']},
        'category': category == null
            ? null
            : {
                '_id': category['id'],
                'name': category['name'],
                'icon': category['icon'],
                'color': category['color'],
              },
      });
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _byId(
      Database db, String table, Set<String> ids) async {
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows =
        await db.rawQuery('SELECT * FROM $table WHERE id IN ($placeholders)', ids.toList());
    return {for (final r in rows) r['id'] as String: r as Map<String, dynamic>};
  }
}

/// Single source of truth for the dashboard. Invalidate after any mutation
/// so balances and recent activity refresh together.
final dashboardOverviewProvider = FutureProvider<DashboardOverview>(
    (ref) => ref.read(dashboardRepositoryProvider).overview());
