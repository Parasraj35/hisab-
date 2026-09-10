import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_exception.dart';
import 'category_model.dart';

const _uuid = Uuid();

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => CategoryRepository());

class CategoryRepository {
  Future<List<Category>> list({String? type}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'categories',
      where: type != null ? 'is_archived = 0 AND type = ?' : 'is_archived = 0',
      whereArgs: type != null ? [type] : null,
      orderBy: 'is_default DESC, name ASC',
    );
    return rows.map((r) => Category.fromJson(_toJson(r))).toList();
  }

  Future<Category> create({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query('categories',
        where: 'name = ? AND type = ?', whereArgs: [name, type]);
    if (existing.isNotEmpty) {
      throw ApiException('That category already exists');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    await db.insert('categories', {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'is_default': 0,
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    });

    final row = (await db.query('categories', where: 'id = ?', whereArgs: [id])).first;
    return Category.fromJson(_toJson(row));
  }

  Future<bool> remove(String id) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (existing.isEmpty) throw ApiException('Category not found');

    final linkedRows = await db.rawQuery(
        'SELECT COUNT(*) as c FROM transactions WHERE category_id = ?', [id]);
    final linked = (linkedRows.first['c'] as int?) ?? 0;

    if (linked > 0) {
      await db.update('categories', {'is_archived': 1}, where: 'id = ?', whereArgs: [id]);
      return true;
    }

    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    return false;
  }

  /// Ported from backend/src/utils/defaults.js's DEFAULT_CATEGORIES — run
  /// once, the moment the local profile is first created (see
  /// AuthController.saveProfile), matching how the old backend seeded a
  /// fresh account on register.
  Future<void> seedDefaults() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = db.batch();
    for (final c in _defaultCategories) {
      batch.insert('categories', {
        'id': _uuid.v4(),
        'name': c.$1,
        'type': c.$2,
        'icon': c.$3,
        'color': c.$4,
        'is_default': 1,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Map<String, dynamic> _toJson(Map<String, dynamic> row) => {
        '_id': row['id'],
        'name': row['name'],
        'type': row['type'],
        'icon': row['icon'],
        'color': row['color'],
        'isDefault': row['is_default'] == 1,
      };
}

// (name, type, icon, color)
const _defaultCategories = [
  ('Food & Dining', 'expense', 'restaurant', '#F97316'),
  ('Transport', 'expense', 'directions_car', '#3B82F6'),
  ('Utilities', 'expense', 'bolt', '#EAB308'),
  ('Shopping', 'expense', 'shopping_bag', '#A855F7'),
  ('Health', 'expense', 'favorite', '#EF4444'),
  ('Education', 'expense', 'school', '#0EA5E9'),
  ('Entertainment', 'expense', 'movie', '#EC4899'),
  ('Others', 'expense', 'category', '#6B7280'),
  ('Salary', 'income', 'payments', '#16A34A'),
  ('Freelance', 'income', 'laptop', '#14B8A6'),
  ('Business', 'income', 'storefront', '#22C55E'),
  ('Gift', 'income', 'card_giftcard', '#F59E0B'),
  ('Other Income', 'income', 'add_circle', '#6B7280'),
];

/// Categories change rarely — cached per type for the pickers.
final categoriesProvider =
    FutureProvider.family<List<Category>, String>((ref, type) async {
  return ref.read(categoryRepositoryProvider).list(type: type);
});
