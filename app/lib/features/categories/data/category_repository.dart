import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'category_model.dart';

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => CategoryRepository(ref.read(apiClientProvider)));

class CategoryRepository {
  CategoryRepository(this._api);
  final ApiClient _api;

  Future<List<Category>> list({String? type}) async {
    final res = await _api.get(ApiEndpoints.categories,
        query: {if (type != null) 'type': type});
    return (res['data']['categories'] as List)
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Category> create({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    final res = await _api.post(ApiEndpoints.categories,
        data: {'name': name, 'type': type, 'icon': icon, 'color': color});
    return Category.fromJson(Map<String, dynamic>.from(res['data']['category']));
  }

  Future<bool> remove(String id) async {
    final res = await _api.delete(ApiEndpoints.category(id));
    return res['data']?['archived'] == true;
  }
}

/// Categories change rarely — cached per type for the pickers.
final categoriesProvider =
    FutureProvider.family<List<Category>, String>((ref, type) async {
  return ref.read(categoryRepositoryProvider).list(type: type);
});
