import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'transaction_model.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
    (ref) => TransactionRepository(ref.read(apiClientProvider)));

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
  TransactionRepository(this._api);
  final ApiClient _api;

  Future<TransactionPage> list(TransactionQuery query) async {
    final res = await _api.get(ApiEndpoints.transactions, query: query.toQuery());
    final meta = Map<String, dynamic>.from(res['meta'] ?? {});
    return TransactionPage(
      items: (res['data'] as List)
          .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      page: (meta['page'] ?? 1) as int,
      totalPages: (meta['totalPages'] ?? 1) as int,
      total: (meta['total'] ?? 0) as int,
    );
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
    final res = await _api.post(ApiEndpoints.transactions, data: {
      'type': type,
      'amount': amount,
      'account': accountId,
      if (toAccountId != null) 'toAccount': toAccountId,
      if (categoryId != null) 'category': categoryId,
      'date': date.toIso8601String(),
      'note': note,
    });
    return TransactionItem.fromJson(
        Map<String, dynamic>.from(res['data']['transaction']));
  }

  Future<TransactionItem> getOne(String id) async {
    final res = await _api.get(ApiEndpoints.transaction(id));
    return TransactionItem.fromJson(
        Map<String, dynamic>.from(res['data']['transaction']));
  }

  Future<TransactionItem> update(String id, Map<String, dynamic> changes) async {
    final res = await _api.patch(ApiEndpoints.transaction(id), data: changes);
    return TransactionItem.fromJson(
        Map<String, dynamic>.from(res['data']['transaction']));
  }

  Future<void> remove(String id) => _api.delete(ApiEndpoints.transaction(id));
}
