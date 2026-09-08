import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/token_storage.dart';
import 'report_model.dart';

enum ReportPeriod { thisMonth, lastMonth, last3Months, thisYear }

extension ReportPeriodX on ReportPeriod {
  String get label => switch (this) {
        ReportPeriod.thisMonth => 'This Month',
        ReportPeriod.lastMonth => 'Last Month',
        ReportPeriod.last3Months => 'Last 3 Months',
        ReportPeriod.thisYear => 'This Year',
      };

  (DateTime, DateTime) get bounds {
    final now = DateTime.now();
    return switch (this) {
      ReportPeriod.thisMonth => (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        ),
      ReportPeriod.lastMonth => (
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 0, 23, 59, 59),
        ),
      ReportPeriod.last3Months => (
          DateTime(now.year, now.month - 2, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        ),
      ReportPeriod.thisYear => (
          DateTime(now.year, 1, 1),
          DateTime(now.year, 12, 31, 23, 59, 59),
        ),
    };
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) =>
    ReportRepository(
        ref.read(apiClientProvider), ref.read(tokenStorageProvider)));

class ReportRepository {
  ReportRepository(this._api, this._storage);
  final ApiClient _api;
  final TokenStorage _storage;

  Future<ReportOverview> overview(ReportPeriod period) async {
    final (from, to) = period.bounds;
    final res = await _api.get(ApiEndpoints.reportOverview, query: {
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    });
    return ReportOverview.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<TrendPoint>> trend({int months = 6}) async {
    final res =
        await _api.get(ApiEndpoints.reportTrend, query: {'months': months});
    return (res['data']['series'] as List)
        .map((e) => TrendPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Downloads the generated file to app storage and returns its local path.
  /// Dio is used directly because this streams bytes, not JSON.
  Future<File> downloadReport({
    required ReportPeriod period,
    required String format, // pdf | csv
    required String type, // summary | detailed
    void Function(int received, int total)? onProgress,
  }) async {
    final (from, to) = period.bounds;
    final token = await _storage.accessToken;

    final dir = await getApplicationDocumentsDirectory();
    final stamp = '${_monthName(from.month)}_${from.year}';
    final path = '${dir.path}/Report_$stamp.$format';

    final dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 60),
    ));

    await dio.download(
      ApiEndpoints.reportExport,
      path,
      queryParameters: {
        'format': format,
        'type': type,
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
      onReceiveProgress: onProgress,
    );

    return File(path);
  }

  static String _monthName(int month) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][month - 1];
}

final reportPeriodProvider =
    StateProvider<ReportPeriod>((ref) => ReportPeriod.thisMonth);

final reportOverviewProvider = FutureProvider<ReportOverview>((ref) {
  final period = ref.watch(reportPeriodProvider);
  return ref.read(reportRepositoryProvider).overview(period);
});

final reportTrendProvider = FutureProvider<List<TrendPoint>>(
    (ref) => ref.read(reportRepositoryProvider).trend());
