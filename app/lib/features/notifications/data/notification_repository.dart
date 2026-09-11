import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/app_database.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        type: (json['type'] ?? 'system').toString(),
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        isRead: json['isRead'] == true,
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString())
                ?.toLocal() ??
            DateTime.now(),
      );
}

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

class NotificationRepository {
  Future<List<AppNotification>> list() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('notifications', orderBy: 'created_at DESC', limit: 50);
    return rows.map((r) => AppNotification.fromJson(_toJson(r))).toList();
  }

  Future<int> unreadCount() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) as c FROM notifications WHERE is_read = 0');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> markRead(String id) async {
    final db = await AppDatabase.instance.database;
    await db.update('notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllRead() async {
    final db = await AppDatabase.instance.database;
    await db.update('notifications', {'is_read': 1}, where: 'is_read = 0');
  }

  Future<void> remove(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('notifications');
  }

  Map<String, dynamic> _toJson(Map<String, dynamic> row) => {
        '_id': row['id'],
        'type': row['type'],
        'title': row['title'],
        'body': row['body'],
        'isRead': row['is_read'] == 1,
        'createdAt': row['created_at'],
      };
}

final notificationsProvider = FutureProvider<List<AppNotification>>(
    (ref) => ref.read(notificationRepositoryProvider).list());
