import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  factory ApiException.fromDio(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException('Cannot reach the server. Check your connection.');
    }

    final data = e.response?.data;
    if (data is Map) {
      final errors = <String, String>{};
      if (data['errors'] is List) {
        for (final item in data['errors']) {
          if (item is Map && item['field'] != null) {
            errors[item['field'].toString()] = item['message'].toString();
          }
        }
      }
      return ApiException(
        (data['message'] ?? 'Something went wrong').toString(),
        statusCode: e.response?.statusCode,
        fieldErrors: errors,
      );
    }
    return ApiException('Something went wrong', statusCode: e.response?.statusCode);
  }

  @override
  String toString() => message;
}
