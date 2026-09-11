import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_exception.dart';
import 'debt_model.dart';

const _uuid = Uuid();

final debtRepositoryProvider = Provider<DebtRepository>((ref) => DebtRepository());

class DebtRepository {
  Future<DebtsPayload> list({String? direction}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'debts',
      where: direction != null ? 'direction = ?' : null,
      whereArgs: direction != null ? [direction] : null,
      orderBy: 'status ASC, due_date ASC, created_at DESC',
    );
    final debts = rows.map((r) => Debt.fromJson(_toJson(r))).toList();

    double lentTotal = 0, lentSettled = 0, borrowedTotal = 0, borrowedSettled = 0;
    final allRows =
        direction != null ? await db.query('debts') : rows; // totals span both directions
    for (final r in allRows) {
      final amount = (r['amount'] as num).toDouble();
      final settled = (r['settled_amount'] as num).toDouble();
      if (r['direction'] == 'lent') {
        lentTotal += amount;
        lentSettled += settled;
      } else {
        borrowedTotal += amount;
        borrowedSettled += settled;
      }
    }

    final currency = await _currency(db);
    return DebtsPayload(
      debts: debts,
      currency: currency,
      summary: DebtSummary.fromJson({
        'lent': {'total': lentTotal, 'received': lentSettled},
        'borrowed': {'total': borrowedTotal, 'repaid': borrowedSettled},
      }),
    );
  }

  Future<Debt> create({
    required String direction,
    required String personName,
    required double amount,
    DateTime? dueDate,
    String note = '',
    String personPhone = '',
  }) async {
    final db = await AppDatabase.instance.database;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    await db.insert('debts', {
      'id': id,
      'direction': direction,
      'person_name': personName,
      'person_phone': personPhone,
      'amount': amount,
      'settled_amount': 0,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'note': note,
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
    });

    final currency = await _currency(db);
    await db.insert('notifications', {
      'id': _uuid.v4(),
      'type': 'debt_reminder',
      'title': direction == 'lent' ? 'Loan Recorded' : 'Borrowing Recorded',
      'body': '$personName · $currency ${amount.toStringAsFixed(2)}',
      'is_read': 0,
      'meta': '{}',
      'created_at': now,
    });

    return _getOne(db, id);
  }

  /// Records a part or full repayment. Over-payment is rejected rather than
  /// silently clamped, so the numbers always reconcile — same rule
  /// debt.controller.js's settleDebt used.
  Future<Debt> settle(String id, double amount, {String note = ''}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('debts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw ApiException('Record not found');
    final row = rows.first;
    if (row['status'] == 'paid') {
      throw ApiException('This record is already settled');
    }

    final amountTotal = (row['amount'] as num).toDouble();
    final settledSoFar = (row['settled_amount'] as num).toDouble();
    final outstanding = amountTotal - settledSoFar;
    if (amount > outstanding) {
      throw ApiException('Only ${outstanding.toStringAsFixed(2)} is outstanding on this record');
    }

    await db.transaction((txn) async {
      await txn.insert('debt_settlements', {
        'id': _uuid.v4(),
        'debt_id': id,
        'amount': amount,
        'date': DateTime.now().toUtc().toIso8601String(),
        'note': note,
      });
      await _recalculateStatus(txn, id);
    });

    final settled = await _getOne(db, id);
    if (settled.status == 'paid') {
      await db.insert('notifications', {
        'id': _uuid.v4(),
        'type': 'debt_reminder',
        'title': 'Record Settled',
        'body': '${settled.personName} is fully settled',
        'is_read': 0,
        'meta': '{}',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    return settled;
  }

  Future<void> remove(String id) async {
    final db = await AppDatabase.instance.database;
    final count = await db.delete('debts', where: 'id = ?', whereArgs: [id]);
    if (count == 0) throw ApiException('Record not found');
  }

  /// Recomputes settled_amount (sum of settlements) and status from it —
  /// a direct port of Debt.js's recalculateStatus.
  Future<void> _recalculateStatus(DatabaseExecutor txn, String debtId) async {
    final rows = await txn.query('debts', where: 'id = ?', whereArgs: [debtId]);
    if (rows.isEmpty) return;
    final amount = (rows.first['amount'] as num).toDouble();

    final sumRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM debt_settlements WHERE debt_id = ?',
        [debtId]);
    final settled = (sumRows.first['total'] as num).toDouble();

    final status = settled <= 0 ? 'pending' : (settled >= amount ? 'paid' : 'partial');

    await txn.update(
      'debts',
      {
        'settled_amount': settled,
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [debtId],
    );
  }

  Future<Debt> _getOne(DatabaseExecutor db, String id) async {
    final rows = await db.query('debts', where: 'id = ?', whereArgs: [id]);
    return Debt.fromJson(_toJson(rows.first));
  }

  Future<String> _currency(DatabaseExecutor db) async {
    final rows = await db.query('profile', columns: ['currency'], limit: 1);
    return rows.isEmpty ? 'PKR' : (rows.first['currency'] as String? ?? 'PKR');
  }

  Map<String, dynamic> _toJson(Map<String, dynamic> row) => {
        '_id': row['id'],
        'direction': row['direction'],
        'personName': row['person_name'],
        'personPhone': row['person_phone'],
        'amount': row['amount'],
        'settledAmount': row['settled_amount'],
        'status': row['status'],
        'note': row['note'],
        'dueDate': row['due_date'],
      };
}

/// Fetches everything once; both tabs filter the same payload client-side,
/// so switching between "I Lent" and "I Borrowed" is instant.
final debtsProvider =
    FutureProvider<DebtsPayload>((ref) => ref.read(debtRepositoryProvider).list());
