import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

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

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        type: (json['type'] ?? 'system').toString(),
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        isRead: json['isRead'] == true,
        createdAt:
            DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal() ??
                DateTime.now(),
      );
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => NotificationRepository(ref.read(apiClientProvider)));

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;

  Future<List<AppNotification>> list() async {
    final res = await _api.get(ApiEndpoints.notifications, query: {'limit': 50});
    return (res['data'] as List)
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markRead(String id) => _api.patch(ApiEndpoints.notificationRead(id));
  Future<void> markAllRead() => _api.patch(ApiEndpoints.notificationsReadAll);
  Future<void> remove(String id) => _api.delete(ApiEndpoints.notification(id));
  Future<void> clearAll() => _api.delete(ApiEndpoints.notifications);
}

final notificationsProvider = FutureProvider<List<AppNotification>>(
    (ref) => ref.read(notificationRepositoryProvider).list());
