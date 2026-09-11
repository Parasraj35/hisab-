import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_exception.dart';
import 'savings_model.dart';

const _uuid = Uuid();

final savingsRepositoryProvider =
    Provider<SavingsRepository>((ref) => SavingsRepository());

class SavingsRepository {
  Future<SavingsPayload> list() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('savings_goals',
        orderBy: 'is_completed ASC, deadline ASC, created_at DESC');
    final goals = rows.map((r) => SavingsGoal.fromJson(_toJson(r))).toList();

    final totalSaved = goals.fold(0.0, (sum, g) => sum + g.savedAmount);
    final totalTarget = goals.fold(0.0, (sum, g) => sum + g.targetAmount);
    final currency = await _currency(db);

    return SavingsPayload(
      goals: goals,
      totalSaved: totalSaved,
      totalTarget: totalTarget,
      currency: currency,
    );
  }

  Future<SavingsGoal> create({
    required String name,
    required double targetAmount,
    double savedAmount = 0,
    DateTime? deadline,
    String icon = 'target',
    String color = '#4CAF8A',
  }) async {
    final db = await AppDatabase.instance.database;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('savings_goals', {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'deadline': deadline?.toUtc().toIso8601String(),
        'icon': icon,
        'color': color,
        'is_completed': savedAmount >= targetAmount ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      });

      // A non-zero starting amount is logged so the ledger stays complete —
      // matches savings.controller.js's createGoal.
      if (savedAmount > 0) {
        await txn.insert('savings_contributions', {
          'id': _uuid.v4(),
          'goal_id': id,
          'amount': savedAmount,
          'date': now,
          'note': 'Opening amount',
        });
      }
    });

    return _getOne(db, id);
  }

  Future<SavingsGoal> contribute(String id, double amount, {String note = ''}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('savings_goals', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw ApiException('Goal not found');
    final wasCompleted = rows.first['is_completed'] == 1;

    await db.transaction((txn) async {
      await txn.insert('savings_contributions', {
        'id': _uuid.v4(),
        'goal_id': id,
        'amount': amount,
        'date': DateTime.now().toUtc().toIso8601String(),
        'note': note,
      });
      await _recalculate(txn, id);
    });

    final goal = await _getOne(db, id);
    if (!wasCompleted && goal.isCompleted) {
      await _pushGoalReachedNotification(db, goal);
    }
    return goal;
  }

  /// Pulling money back out of a goal — stored as a negative contribution
  /// so the log reads as a full history, same convention
  /// savings.controller.js's withdraw() used.
  Future<SavingsGoal> withdraw(String id, double amount, {String note = ''}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('savings_goals', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw ApiException('Goal not found');
    final savedAmount = (rows.first['saved_amount'] as num).toDouble();
    if (amount > savedAmount) {
      throw ApiException('Only ${savedAmount.toStringAsFixed(2)} is saved in this goal');
    }

    await db.transaction((txn) async {
      await txn.insert('savings_contributions', {
        'id': _uuid.v4(),
        'goal_id': id,
        'amount': -amount,
        'date': DateTime.now().toUtc().toIso8601String(),
        'note': note.isEmpty ? 'Withdrawal' : note,
      });
      await _recalculate(txn, id);
    });

    return _getOne(db, id);
  }

  Future<void> remove(String id) async {
    final db = await AppDatabase.instance.database;
    final count = await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
    if (count == 0) throw ApiException('Goal not found');
  }

  /// Keeps saved_amount and is_completed in agreement with the
  /// contribution log — a direct port of savings.controller.js's
  /// recalculate().
  Future<void> _recalculate(DatabaseExecutor txn, String goalId) async {
    final sumRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM savings_contributions WHERE goal_id = ?',
        [goalId]);
    final saved = (sumRows.first['total'] as num).toDouble();

    final goalRows = await txn.query('savings_goals', where: 'id = ?', whereArgs: [goalId]);
    if (goalRows.isEmpty) return;
    final target = (goalRows.first['target_amount'] as num).toDouble();

    await txn.update(
      'savings_goals',
      {
        'saved_amount': saved,
        'is_completed': saved >= target ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );
  }

  Future<void> _pushGoalReachedNotification(DatabaseExecutor db, SavingsGoal goal) async {
    await db.insert('notifications', {
      'id': _uuid.v4(),
      'type': 'system',
      'title': 'Goal Reached',
      'body': 'You hit your ${goal.name} target',
      'is_read': 0,
      'meta': '{}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<SavingsGoal> _getOne(DatabaseExecutor db, String id) async {
    final rows = await db.query('savings_goals', where: 'id = ?', whereArgs: [id]);
    return SavingsGoal.fromJson(_toJson(rows.first));
  }

  Future<String> _currency(DatabaseExecutor db) async {
    final rows = await db.query('profile', columns: ['currency'], limit: 1);
    return rows.isEmpty ? 'PKR' : (rows.first['currency'] as String? ?? 'PKR');
  }

  Map<String, dynamic> _toJson(Map<String, dynamic> row) => {
        '_id': row['id'],
        'name': row['name'],
        'targetAmount': row['target_amount'],
        'savedAmount': row['saved_amount'],
        'isCompleted': row['is_completed'] == 1,
        'icon': row['icon'],
        'color': row['color'],
        'deadline': row['deadline'],
      };
}

final savingsProvider =
    FutureProvider<SavingsPayload>((ref) => ref.read(savingsRepositoryProvider).list());
