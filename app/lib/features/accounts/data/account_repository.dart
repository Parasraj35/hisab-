import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'account_model.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
    (ref) => AccountRepository(ref.read(apiClientProvider)));

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
  AccountRepository(this._api);
  final ApiClient _api;

  Future<AccountsPayload> list({bool includeArchived = false}) async {
    final res = await _api.get(ApiEndpoints.accounts,
        query: {'includeArchived': includeArchived.toString()});
    final data = res['data'] as Map<String, dynamic>;
    return AccountsPayload(
      accounts: (data['accounts'] as List)
          .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalBalance: (data['totalBalance'] ?? 0).toDouble(),
      currency: (data['currency'] ?? 'PKR').toString(),
    );
  }

  Future<Account> create({
    required String name,
    required String type,
    required String currency,
    required double initialBalance,
  }) async {
    final res = await _api.post(ApiEndpoints.accounts, data: {
      'name': name,
      'type': type,
      'currency': currency,
      'initialBalance': initialBalance,
    });
    return Account.fromJson(Map<String, dynamic>.from(res['data']['account']));
  }

  Future<Account> update(String id, Map<String, dynamic> changes) async {
    final res = await _api.patch(ApiEndpoints.account(id), data: changes);
    return Account.fromJson(Map<String, dynamic>.from(res['data']['account']));
  }

  /// Returns true when the server archived instead of deleting (account had history).
  Future<bool> remove(String id) async {
    final res = await _api.delete(ApiEndpoints.account(id));
    return res['data']?['archived'] == true;
  }

  Future<void> setDefault(String id) =>
      _api.post(ApiEndpoints.accountDefault(id));
}
