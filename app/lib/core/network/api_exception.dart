import 'package:dio/dio.dart';

/// User-facing error surfaced from the local data layer (validation,
/// conflicts, not-found). Kept under its old name/shape — screens already
/// catch these generically and display `e.toString()` — even though it no
/// longer wraps a Dio/HTTP failure now that most repositories are
/// local-only. `fromDio` stays only for the repositories api_client.dart
/// still serves (settings/report) until Phase 5/6 finishes removing them.
class ApiException implements Exception {
  ApiException(this.message, {this.fieldErrors = const {}});

  final String message;
  final Map<String, String> fieldErrors;

  factory ApiException.fromDio(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException('Cannot reach the server. Check your connection.');
    }
    final data = e.response?.data;
    if (data is Map) {
      return ApiException((data['message'] ?? 'Something went wrong').toString());
    }
    return ApiException('Something went wrong');
  }

  @override
  String toString() => message;
}
