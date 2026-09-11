import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The app's single local SQLite store. Table/field names mirror the field
/// names used by the old backend's Mongoose models (backend/src/models/) so
/// the migration away from the server was a like-for-like port, not a
/// redesign — see each repository for where a given table's shape traces
/// back to its Mongo counterpart.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final opened = await _open();
    _db = opened;
    return opened;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'hisab.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final batch = db.batch();
        _createSchema(batch);
        await batch.commit(noResult: true);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Login/signup came back after being removed — the local profile
          // row now needs a password to check and a flag for whether this
          // device is currently "logged in" (there's no server session to
          // hold that state, so it lives right on the row).
          await db.execute(
              "ALTER TABLE profile ADD COLUMN password_hash TEXT NOT NULL DEFAULT ''");
          await db.execute(
              'ALTER TABLE profile ADD COLUMN is_logged_in INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }

  void _createSchema(Batch b) {
    // ---- profile — single row, fixed id 'local'. Mirrors User.js, with
    // password_hash/is_logged_in standing in for what used to be
    // password+JWT — login is now just "does this device know the
    // password", not a server session.
    b.execute('''
      CREATE TABLE profile (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        password_hash TEXT NOT NULL DEFAULT '',
        is_logged_in INTEGER NOT NULL DEFAULT 0,
        avatar_path TEXT NOT NULL DEFAULT '',
        currency TEXT NOT NULL DEFAULT 'PKR',
        theme TEXT NOT NULL DEFAULT 'system',
        language TEXT NOT NULL DEFAULT 'en',
        app_lock INTEGER NOT NULL DEFAULT 0,
        biometric_unlock INTEGER NOT NULL DEFAULT 0,
        auto_lock_minutes INTEGER NOT NULL DEFAULT 1,
        notif_transactions INTEGER NOT NULL DEFAULT 1,
        notif_debt_reminders INTEGER NOT NULL DEFAULT 1,
        notif_weekly_report INTEGER NOT NULL DEFAULT 1,
        onboarding_stage TEXT NOT NULL DEFAULT 'profile',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ---- accounts — mirrors Account.js
    b.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'cash',
        icon TEXT NOT NULL DEFAULT 'wallet',
        color TEXT NOT NULL DEFAULT '#16A34A',
        currency TEXT NOT NULL DEFAULT 'PKR',
        initial_balance REAL NOT NULL DEFAULT 0,
        current_balance REAL NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    b.execute(
        'CREATE UNIQUE INDEX idx_accounts_name ON accounts(name)');
    b.execute(
        'CREATE INDEX idx_accounts_archived ON accounts(is_archived)');

    // ---- categories — mirrors Category.js
    b.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'tag',
        color TEXT NOT NULL DEFAULT '#16A34A',
        is_default INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    b.execute(
        'CREATE UNIQUE INDEX idx_categories_name_type ON categories(name, type)');
    b.execute(
        'CREATE INDEX idx_categories_type ON categories(type, is_archived)');

    // ---- transactions — mirrors Transaction.js. account_id/to_account_id/
    // category_id intentionally have no FK constraint (accounts/categories
    // can be archived-not-deleted, same as the backend) but every one of
    // them is indexed since they're all filter/join columns.
    b.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        account_id TEXT NOT NULL,
        to_account_id TEXT,
        category_id TEXT,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        transfer_group TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    b.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    b.execute('CREATE INDEX idx_tx_type_date ON transactions(type, date)');
    b.execute('CREATE INDEX idx_tx_account_date ON transactions(account_id, date)');
    b.execute(
        'CREATE INDEX idx_tx_to_account ON transactions(to_account_id)');
    b.execute('CREATE INDEX idx_tx_category ON transactions(category_id)');

    // ---- debts + settlements — mirrors Debt.js (settlements was an
    // embedded subdocument array in Mongo; normalised to its own table here
    // since SQLite has no native array/embedded-document type).
    b.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        direction TEXT NOT NULL,
        person_name TEXT NOT NULL,
        person_avatar TEXT NOT NULL DEFAULT '',
        person_phone TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL,
        settled_amount REAL NOT NULL DEFAULT 0,
        account_id TEXT,
        due_date TEXT,
        note TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    b.execute('CREATE INDEX idx_debts_status ON debts(status)');
    b.execute('CREATE INDEX idx_debts_direction ON debts(direction)');

    b.execute('''
      CREATE TABLE debt_settlements (
        id TEXT PRIMARY KEY,
        debt_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (debt_id) REFERENCES debts(id) ON DELETE CASCADE
      )
    ''');
    b.execute(
        'CREATE INDEX idx_settlements_debt ON debt_settlements(debt_id)');

    // ---- savings goals + contributions — mirrors SavingsGoal.js. A
    // withdrawal is stored as a negative contribution row, same convention
    // the backend used (see savings.controller.js's withdraw()).
    b.execute('''
      CREATE TABLE savings_goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0,
        deadline TEXT,
        icon TEXT NOT NULL DEFAULT 'target',
        color TEXT NOT NULL DEFAULT '#16A34A',
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    b.execute(
        'CREATE INDEX idx_savings_completed ON savings_goals(is_completed)');

    b.execute('''
      CREATE TABLE savings_contributions (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (goal_id) REFERENCES savings_goals(id) ON DELETE CASCADE
      )
    ''');
    b.execute(
        'CREATE INDEX idx_contributions_goal ON savings_contributions(goal_id)');

    // ---- notifications — mirrors Notification.js
    b.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL DEFAULT 'system',
        title TEXT NOT NULL,
        body TEXT NOT NULL DEFAULT '',
        is_read INTEGER NOT NULL DEFAULT 0,
        meta TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL
      )
    ''');
    b.execute(
        'CREATE INDEX idx_notifications_created ON notifications(created_at)');
    b.execute(
        'CREATE INDEX idx_notifications_unread ON notifications(is_read)');
  }

  /// Test/dev-only escape hatch — Phase 6's "reset app data" action.
  Future<void> wipeAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'debt_settlements',
        'savings_contributions',
        'debts',
        'savings_goals',
        'transactions',
        'categories',
        'accounts',
        'notifications',
        'profile',
      ]) {
        await txn.delete(table);
      }
    });
  }
}
