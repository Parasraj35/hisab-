import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
final apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.read(tokenStorageProvider)));

class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.accessToken;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        // One silent refresh attempt on 401, then replay the original request.
        final isAuthCall = error.requestOptions.path.contains('/auth/login') ||
            error.requestOptions.path.contains('/auth/register') ||
            error.requestOptions.path.contains('/auth/refresh');

        if (error.response?.statusCode == 401 && !isAuthCall && !_refreshing) {
          _refreshing = true;
          try {
            final refresh = await _storage.refreshToken;
            if (refresh != null) {
              final res = await Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl))
                  .post(ApiEndpoints.refresh, data: {'refreshToken': refresh});
              final tokens = res.data['data']['tokens'];
              await _storage.saveTokens(
                access: tokens['accessToken'],
                refresh: tokens['refreshToken'],
              );
              _refreshing = false;
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer ${tokens['accessToken']}';
              final retry = await _dio.fetch(opts);
              return handler.resolve(retry);
            }
          } catch (_) {
            await _storage.clear();
          }
          _refreshing = false;
        }
        handler.next(error);
      },
    ));
  }

  late final Dio _dio;
  final TokenStorage _storage;
  bool _refreshing = false;

  Future<Map<String, dynamic>> get(String path,
          {Map<String, dynamic>? query}) =>
      _wrap(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? data}) =>
      _wrap(() => _dio.post(path, data: data));

  Future<Map<String, dynamic>> patch(String path, {Object? data}) =>
      _wrap(() => _dio.patch(path, data: data));

  Future<Map<String, dynamic>> delete(String path, {Object? data}) =>
      _wrap(() => _dio.delete(path, data: data));

  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String fieldName,
    required String filePath,
  }) =>
      _wrap(() => _dio.post(path,
          data: FormData.fromMap(
              {fieldName: MultipartFile.fromFileSync(filePath)})));

  Future<Map<String, dynamic>> _wrap(Future<Response> Function() call) async {
    try {
      final res = await call();
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
