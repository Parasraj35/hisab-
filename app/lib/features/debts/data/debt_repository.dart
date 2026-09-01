import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'debt_model.dart';

final debtRepositoryProvider =
    Provider<DebtRepository>((ref) => DebtRepository(ref.read(apiClientProvider)));

class DebtRepository {
  DebtRepository(this._api);
  final ApiClient _api;

  Future<DebtsPayload> list({String? direction}) async {
    final res = await _api.get(ApiEndpoints.debts,
        query: {if (direction != null) 'direction': direction});
    final data = res['data'] as Map<String, dynamic>;
    return DebtsPayload(
      debts: (data['debts'] as List)
          .map((e) => Debt.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      summary: DebtSummary.fromJson(Map<String, dynamic>.from(data['summary'])),
      currency: (data['currency'] ?? 'PKR').toString(),
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
    final res = await _api.post(ApiEndpoints.debts, data: {
      'direction': direction,
      'personName': personName,
      'amount': amount,
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      'note': note,
      'personPhone': personPhone,
    });
    return Debt.fromJson(Map<String, dynamic>.from(res['data']['debt']));
  }

  Future<Debt> settle(String id, double amount, {String note = ''}) async {
    final res = await _api.post(ApiEndpoints.debtSettle(id),
        data: {'amount': amount, 'note': note});
    return Debt.fromJson(Map<String, dynamic>.from(res['data']['debt']));
  }

  Future<void> remove(String id) => _api.delete(ApiEndpoints.debt(id));
}

/// Fetches everything once; both tabs filter the same payload client-side,
/// so switching between "I Lent" and "I Borrowed" is instant.
final debtsProvider =
    FutureProvider<DebtsPayload>((ref) => ref.read(debtRepositoryProvider).list());
