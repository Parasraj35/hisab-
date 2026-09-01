import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'savings_model.dart';

final savingsRepositoryProvider = Provider<SavingsRepository>(
    (ref) => SavingsRepository(ref.read(apiClientProvider)));

class SavingsRepository {
  SavingsRepository(this._api);
  final ApiClient _api;

  Future<SavingsPayload> list() async {
    final res = await _api.get(ApiEndpoints.savings);
    final data = res['data'] as Map<String, dynamic>;
    final summary = Map<String, dynamic>.from(data['summary'] ?? {});
    return SavingsPayload(
      goals: (data['goals'] as List)
          .map((e) => SavingsGoal.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalSaved: (summary['totalSaved'] ?? 0).toDouble(),
      totalTarget: (summary['totalTarget'] ?? 0).toDouble(),
      currency: (data['currency'] ?? 'PKR').toString(),
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
    final res = await _api.post(ApiEndpoints.savings, data: {
      'name': name,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
      'icon': icon,
      'color': color,
    });
    return SavingsGoal.fromJson(Map<String, dynamic>.from(res['data']['goal']));
  }

  Future<SavingsGoal> contribute(String id, double amount, {String note = ''}) async {
    final res = await _api.post(ApiEndpoints.savingsContribute(id),
        data: {'amount': amount, 'note': note});
    return SavingsGoal.fromJson(Map<String, dynamic>.from(res['data']['goal']));
  }

  Future<SavingsGoal> withdraw(String id, double amount, {String note = ''}) async {
    final res = await _api.post(ApiEndpoints.savingsWithdraw(id),
        data: {'amount': amount, 'note': note});
    return SavingsGoal.fromJson(Map<String, dynamic>.from(res['data']['goal']));
  }

  Future<void> remove(String id) => _api.delete(ApiEndpoints.savingsGoal(id));
}

final savingsProvider = FutureProvider<SavingsPayload>(
    (ref) => ref.read(savingsRepositoryProvider).list());
