import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_exception.dart';
import '../../accounts/data/account_repository.dart';
import 'transaction_model.dart';

const _uuid = Uuid();

final transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) => TransactionRepository());

class TransactionQuery {
  const TransactionQuery({
    this.type,
    this.accountId,
    this.categoryId,
    this.from,
    this.to,
    this.search,
    this.minAmount,
    this.maxAmount,
    this.page = 1,
    this.limit = 20,
  });

  final String? type;
  final String? accountId;
  final String? categoryId;
  final DateTime? from;
  final DateTime? to;
  final String? search;
  final double? minAmount;
  final double? maxAmount;
  final int page;
  final int limit;

  Map<String, dynamic> toQuery() => {
        if (type != null) 'type': type,
        if (accountId != null) 'account': accountId,
        if (categoryId != null) 'category': categoryId,
        if (from != null) 'from': from!.toIso8601String(),
        if (to != null) 'to': to!.toIso8601String(),
        if (search != null && search!.isNotEmpty) 'search': search,
        if (minAmount != null) 'minAmount': minAmount,
        if (maxAmount != null) 'maxAmount': maxAmount,
        'page': page,
        'limit': limit,
      };

  TransactionQuery copyWith({int? page}) => TransactionQuery(
        type: type,
        accountId: accountId,
        categoryId: categoryId,
        from: from,
        to: to,
        search: search,
        minAmount: minAmount,
        maxAmount: maxAmount,
        page: page ?? this.page,
        limit: limit,
      );
}

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
  final List<TransactionItem> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;
}

class TransactionRepository {
  Future<TransactionPage> list(TransactionQuery query) async {
    final db = await AppDatabase.instance.database;
    final where = <String>[];
    final args = <Object?>[];

    if (query.type != null) {
      where.add('type = ?');
      args.add(query.type);
    }
    if (query.accountId != null) {
      where.add('(account_id = ? OR to_account_id = ?)');
      args.addAll([query.accountId, query.accountId]);
    }
    if (query.categoryId != null) {
      where.add('category_id = ?');
      args.add(query.categoryId);
    }
    if (query.from != null) {
      where.add('date >= ?');
      args.add(_startOfDay(query.from!).toUtc().toIso8601String());
    }
    if (query.to != null) {
      where.add('date <= ?');
      args.add(_endOfDay(query.to!).toUtc().toIso8601String());
    }
    if (query.minAmount != null) {
      where.add('amount >= ?');
      args.add(query.minAmount);
    }
    if (query.maxAmount != null) {
      where.add('amount <= ?');
      args.add(query.maxAmount);
    }
    if (query.search != null && query.search!.isNotEmpty) {
      where.add('note LIKE ?');
      args.add('%${query.search}%');
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final totalRows = await db
        .rawQuery('SELECT COUNT(*) as c FROM transactions $whereClause', args);
    final total = (totalRows.first['c'] as int?) ?? 0;

    final offset = (query.page - 1) * query.limit;
    final rows = await db.rawQuery(
      'SELECT * FROM transactions $whereClause ORDER BY date DESC, created_at DESC LIMIT ? OFFSET ?',
      [...args, query.limit, offset],
    );

    final items = await _hydrate(db, rows);
    final totalPages = total == 0 ? 1 : (total / query.limit).ceil();

    return TransactionPage(
        items: items, page: query.page, totalPages: totalPages, total: total);
  }

  Future<TransactionItem> create({
    required String type,
    required double amount,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required DateTime date,
    String note = '',
  }) async {
    final db = await AppDatabase.instance.database;
    await _assertExists(db, accountId, toAccountId, categoryId);

    if (type == 'transfer') {
      if (toAccountId == null) {
        throw ApiException('Destination account is required for a transfer');
      }
      if (toAccountId == accountId) {
        throw ApiException('Choose a different destination account');
      }
    } else if (categoryId == null) {
      throw ApiException('Category is required');
    }

    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    // Insert + balance recompute run atomically so a rejected (would-go-
    // negative) transaction never leaves a half-applied row behind.
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': id,
        'type': type,
        'amount': amount,
        'account_id': accountId,
        'to_account_id': type == 'transfer' ? toAccountId : null,
        'category_id': type == 'transfer' ? null : categoryId,
        'date': date.toUtc().toIso8601String(),
        'note': note,
        'transfer_group': type == 'transfer' ? _uuid.v4() : null,
        'created_at': now,
        'updated_at': now,
      });

      await recomputeAccounts(txn, [accountId, toAccountId]);
    });

    if (type != 'transfer') {
      await _pushNotification(db, type: type, amount: amount);
    }

    return getOne(id);
  }

  Future<void> _pushNotification(
      DatabaseExecutor db, {required String type, required double amount}) async {
    final currencyRows = await db.query('profile', columns: ['currency'], limit: 1);
    final currency =
        currencyRows.isEmpty ? 'PKR' : (currencyRows.first['currency'] as String? ?? 'PKR');
    final isExpense = type == 'expense';

    await db.insert('notifications', {
      'id': _uuid.v4(),
      'type': type,
      'title': isExpense ? 'Expense Added' : 'Income Added',
      'body': 'You added a new ${isExpense ? 'expense' : 'income'} of '
          '$currency ${amount.toStringAsFixed(2)}',
      'is_read': 0,
      'meta': '{}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<TransactionItem> getOne(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw ApiException('Transaction not found');
    final items = await _hydrate(db, rows);
    return items.first;
  }

  Future<TransactionItem> update(String id, Map<String, dynamic> changes) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (existing.isEmpty) throw ApiException('Transaction not found');
    final row = existing.first;

    final previousAccounts = [
      row['account_id'] as String?,
      row['to_account_id'] as String?,
    ];

    final newAccountId = (changes['account'] as String?) ?? row['account_id'] as String;
    final newToAccountId =
        changes.containsKey('toAccount') ? changes['toAccount'] as String? : row['to_account_id'] as String?;
    final newCategoryId =
        changes.containsKey('category') ? changes['category'] as String? : row['category_id'] as String?;

    await _assertExists(db, newAccountId, newToAccountId, newCategoryId);

    final columns = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (changes.containsKey('amount')) columns['amount'] = changes['amount'];
    if (changes.containsKey('account')) columns['account_id'] = changes['account'];
    if (changes.containsKey('toAccount')) columns['to_account_id'] = changes['toAccount'];
    if (changes.containsKey('category')) columns['category_id'] = changes['category'];
    if (changes.containsKey('date')) {
      columns['date'] = DateTime.parse(changes['date'] as String).toUtc().toIso8601String();
    }
    if (changes.containsKey('note')) columns['note'] = changes['note'];

    // Update + balance recompute run atomically — the same "no half-applied
    // row" guarantee as create().
    await db.transaction((txn) async {
      await txn.update('transactions', columns, where: 'id = ?', whereArgs: [id]);

      // Recompute both the old and new accounts — an edit can move money
      // between them (balance.service.js's recomputeAccounts call site).
      await recomputeAccounts(txn, [...previousAccounts, newAccountId, newToAccountId]);
    });

    return getOne(id);
  }

  Future<void> remove(String id) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (existing.isEmpty) throw ApiException('Transaction not found');
    final row = existing.first;
    final affected = [row['account_id'] as String?, row['to_account_id'] as String?];

    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      await recomputeAccounts(txn, affected);
    });
  }

  Future<void> _assertExists(
      Database db, String accountId, String? toAccountId, String? categoryId) async {
    final ids = {accountId, if (toAccountId != null) toAccountId};
    final placeholders = List.filled(ids.length, '?').join(',');
    final accounts = await db
        .rawQuery('SELECT id FROM accounts WHERE id IN ($placeholders)', ids.toList());
    if (accounts.length != ids.length) {
      throw ApiException('One of the selected accounts does not exist');
    }
    if (categoryId != null) {
      final cats =
          await db.query('categories', where: 'id = ?', whereArgs: [categoryId]);
      if (cats.isEmpty) throw ApiException('Selected category does not exist');
    }
  }

  Future<List<TransactionItem>> _hydrate(
      Database db, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final accountIds = <String>{};
    final categoryIds = <String>{};
    for (final r in rows) {
      if (r['account_id'] != null) accountIds.add(r['account_id'] as String);
      if (r['to_account_id'] != null) accountIds.add(r['to_account_id'] as String);
      if (r['category_id'] != null) categoryIds.add(r['category_id'] as String);
    }

    final accounts = await _rowsById(db, 'accounts', accountIds);
    final categories = await _rowsById(db, 'categories', categoryIds);

    return rows.map((r) {
      final accountRow = accounts[r['account_id']];
      final toAccountRow = accounts[r['to_account_id']];
      final categoryRow = categories[r['category_id']];
      return TransactionItem.fromJson({
        '_id': r['id'],
        'type': r['type'],
        'amount': r['amount'],
        'date': r['date'],
        'note': r['note'],
        'account': accountRow == null ? null : _accountJson(accountRow),
        'toAccount': toAccountRow == null ? null : _accountJson(toAccountRow),
        'category': categoryRow == null ? null : _categoryJson(categoryRow),
      });
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _rowsById(
      Database db, String table, Set<String> ids) async {
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows =
        await db.rawQuery('SELECT * FROM $table WHERE id IN ($placeholders)', ids.toList());
    return {for (final r in rows) r['id'] as String: r};
  }

  Map<String, dynamic> _accountJson(Map<String, dynamic> r) => {
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
      };

  Map<String, dynamic> _categoryJson(Map<String, dynamic> r) => {
        '_id': r['id'],
        'name': r['name'],
        'type': r['type'],
        'icon': r['icon'],
        'color': r['color'],
        'isDefault': r['is_default'] == 1,
      };

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
}
