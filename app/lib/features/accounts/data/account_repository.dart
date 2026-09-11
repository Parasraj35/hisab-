import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_exception.dart';
import 'account_model.dart';

const _uuid = Uuid();

// Same account-type icon/color defaults the old backend used
// (backend/src/utils/defaults.js) — applied whenever a caller doesn't pass
// an explicit icon/color, same as the server did.
const _typeDefaults = {
  'cash': ('payments', '#22A447'),
  'bank': ('account_balance', '#3B82F6'),
  'wallet': ('account_balance_wallet', '#8B5CF6'),
  'card': ('credit_card', '#F59E0B'),
  'other': ('wallet', '#6B7280'),
};

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository());

class AccountsPayload {
  const AccountsPayload(
      {required this.accounts,
      required this.totalBalance,
      required this.currency});
  final List<Account> accounts;
  final double totalBalance;
  final String currency;
}

class AccountRepository {
  Future<AccountsPayload> list({bool includeArchived = false}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounts',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'is_default DESC, created_at ASC',
    );
    final accounts = rows.map((r) => Account.fromJson(_toJson(r))).toList();
    final totalBalance = accounts
        .where((a) => !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.currentBalance);

    final currency = await _currency(db);
    return AccountsPayload(
        accounts: accounts, totalBalance: totalBalance, currency: currency);
  }

  Future<Account> create({
    required String name,
    required String type,
    required String currency,
    required double initialBalance,
  }) async {
    final db = await AppDatabase.instance.database;

    final existing =
        await db.query('accounts', where: 'name = ?', whereArgs: [name]);
    if (existing.isNotEmpty) {
      throw ApiException('You already have an account with that name');
    }

    final isFirst =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM accounts')) == 0;
    final defaults = _typeDefaults[type] ?? _typeDefaults['other']!;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();

    await db.insert('accounts', {
      'id': id,
      'name': name,
      'type': type,
      'icon': defaults.$1,
      'color': defaults.$2,
      'currency': currency,
      'initial_balance': initialBalance,
      'current_balance': initialBalance,
      'is_default': isFirst ? 1 : 0,
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    });

    final row = (await db.query('accounts', where: 'id = ?', whereArgs: [id])).first;
    return Account.fromJson(_toJson(row));
  }

  Future<Account> update(String id, Map<String, dynamic> changes) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (existing.isEmpty) throw ApiException('Account not found');

    final oldInitial = (existing.first['initial_balance'] as num).toDouble();
    final columns = <String, dynamic>{'updated_at': DateTime.now().toUtc().toIso8601String()};
    if (changes.containsKey('name')) columns['name'] = changes['name'];
    if (changes.containsKey('type')) columns['type'] = changes['type'];
    if (changes.containsKey('icon')) columns['icon'] = changes['icon'];
    if (changes.containsKey('color')) columns['color'] = changes['color'];
    if (changes.containsKey('currency')) columns['currency'] = changes['currency'];
    if (changes.containsKey('isArchived')) {
      columns['is_archived'] = changes['isArchived'] == true ? 1 : 0;
    }

    double? newInitial;
    if (changes.containsKey('initialBalance')) {
      newInitial = (changes['initialBalance'] as num).toDouble();
      columns['initial_balance'] = newInitial;
    }

    await db.update('accounts', columns, where: 'id = ?', whereArgs: [id]);

    // Changing the opening balance shifts every derived balance after it —
    // mirrors balance.service.js's recomputeAccountBalance.
    if (newInitial != null && newInitial != oldInitial) {
      await recomputeAccountBalance(db, id);
    }

    final row = (await db.query('accounts', where: 'id = ?', whereArgs: [id])).first;
    return Account.fromJson(_toJson(row));
  }

  /// Returns true when archived instead of deleted (account had history).
  Future<bool> remove(String id) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (existing.isEmpty) throw ApiException('Account not found');

    final linked = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM transactions WHERE account_id = ? OR to_account_id = ?',
          [id, id],
        )) ??
        0;

    if (linked > 0) {
      await db.update('accounts', {'is_archived': 1}, where: 'id = ?', whereArgs: [id]);
      return true;
    }

    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    return false;
  }

  Future<void> setDefault(String id) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.update('accounts', {'is_default': 0});
      await txn.update('accounts', {'is_default': 1}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<String> _currency(Database db) async {
    final rows = await db.query('profile', columns: ['currency'], limit: 1);
    return rows.isEmpty ? 'PKR' : (rows.first['currency'] as String? ?? 'PKR');
  }

  Map<String, dynamic> _toJson(Map<String, dynamic> row) => {
        '_id': row['id'],
        'name': row['name'],
        'type': row['type'],
        'icon': row['icon'],
        'color': row['color'],
        'currency': row['currency'],
        'initialBalance': row['initial_balance'],
        'currentBalance': row['current_balance'],
        'isDefault': row['is_default'] == 1,
        'isArchived': row['is_archived'] == 1,
      };
}

/// Recomputes one account's balance from its opening balance plus every
/// income/expense/transfer that touches it — a direct port of
/// balance.service.js's recomputeAccountBalance, down to the exact
/// inflow/outflow split (income-on-this-account and transfer-in count as
/// inflow; expense-on-this-account and transfer-out count as outflow).
Future<void> recomputeAccountBalance(DatabaseExecutor db, String accountId) async {
  final row = await db.query('accounts', where: 'id = ?', whereArgs: [accountId]);
  if (row.isEmpty) return;
  final initialBalance = (row.first['initial_balance'] as num).toDouble();

  final inflowRows = await db.rawQuery('''
    SELECT COALESCE(SUM(amount), 0) as total FROM transactions
    WHERE (type = 'income' AND account_id = ?)
       OR (type = 'transfer' AND to_account_id = ?)
  ''', [accountId, accountId]);
  final outflowRows = await db.rawQuery('''
    SELECT COALESCE(SUM(amount), 0) as total FROM transactions
    WHERE (type = 'expense' AND account_id = ?)
       OR (type = 'transfer' AND account_id = ?)
  ''', [accountId, accountId]);

  final inflow = (inflowRows.first['total'] as num).toDouble();
  final outflow = (outflowRows.first['total'] as num).toDouble();

  await db.update(
    'accounts',
    {'current_balance': initialBalance + inflow - outflow},
    where: 'id = ?',
    whereArgs: [accountId],
  );
}

/// Recomputes several accounts at once — a direct port of
/// balance.service.js's recomputeAccounts (dedupes and skips nulls, the
/// same way it did when accountIds came from a transaction's
/// account/toAccount pair) — then enforces that none of them went negative.
/// Call this from inside a `db.transaction()` block so a rejection rolls
/// back the transaction row that caused it, not just the balance update.
Future<void> recomputeAccounts(DatabaseExecutor db, List<String?> accountIds) async {
  final unique = {...accountIds.whereType<String>()};
  for (final id in unique) {
    await recomputeAccountBalance(db, id);
  }

  for (final id in unique) {
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) continue;
    final balance = (rows.first['current_balance'] as num).toDouble();
    if (balance < 0) {
      final name = rows.first['name'] as String? ?? 'This account';
      throw ApiException(
        '$name doesn\'t have enough balance for this '
        '(it would go to ${balance.toStringAsFixed(2)}).',
      );
    }
  }
}
