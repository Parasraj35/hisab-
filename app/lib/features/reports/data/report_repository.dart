import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';
import '../../../core/local_db/app_database.dart';
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

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

final reportRepositoryProvider =
    Provider<ReportRepository>((ref) => ReportRepository());

/// A direct port of report.controller.js's overview()/trend() — totals and
/// category breakdowns become SQL GROUP BY queries — plus local PDF/CSV
/// generation (via the `pdf` package) replacing what used to be a server
/// download, since there's no server to stream one from anymore.
class ReportRepository {
  Future<ReportOverview> overview(ReportPeriod period) async {
    final db = await AppDatabase.instance.database;
    final (from, to) = period.bounds;

    final totals = await _totals(db, from, to);
    final expenseByCategory = await _categoryBreakdown(db, from, to, 'expense');
    final incomeByCategory = await _categoryBreakdown(db, from, to, 'income');
    final currency = await _currency(db);
    final days = to.difference(from).inDays + 1;

    return ReportOverview(
      currency: currency,
      rangeLabel: '${_fmtShort(from)} – ${_fmtShort(to)}',
      totals: ReportTotals(
        income: totals.$1,
        expense: totals.$2,
        net: totals.$1 - totals.$2,
        transactionCount: totals.$3,
        avgDailySpend: days > 0 ? totals.$2 / days : totals.$2,
        savingsRate: totals.$1 > 0 ? (totals.$1 - totals.$2) / totals.$1 : 0,
      ),
      expenseByCategory: expenseByCategory,
      incomeByCategory: incomeByCategory,
    );
  }

  Future<List<TrendPoint>> trend({int months = 6}) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final points = <TrendPoint>[];

    for (var i = months - 1; i >= 0; i--) {
      final point = DateTime(now.year, now.month - i, 1);
      final start = DateTime(point.year, point.month, 1);
      final end = DateTime(point.year, point.month + 1, 0, 23, 59, 59, 999);
      final (income, expense, _) = await _totals(db, start, end);
      points.add(TrendPoint(
          label: _monthNames[point.month - 1], income: income, expense: expense));
    }
    return points;
  }

  /// Generates the report file on-device and returns its local path —
  /// replaces the old server-streamed download.
  Future<File> downloadReport({
    required ReportPeriod period,
    required String format, // pdf | csv
    required String type, // summary | detailed
    void Function(int received, int total)? onProgress,
  }) async {
    final db = await AppDatabase.instance.database;
    final (from, to) = period.bounds;
    final currency = await _currency(db);
    final overviewData = await overview(period);
    final rows = type == 'detailed'
        ? await _reportTransactions(db, from, to)
        : <Map<String, dynamic>>[];

    final dir = await getApplicationDocumentsDirectory();
    final stamp = '${_monthNames[from.month - 1]}_${from.year}';
    final path = '${dir.path}/Report_$stamp.$format';
    final file = File(path);

    if (format == 'csv') {
      await file.writeAsString(_buildCsv(rows, currency));
    } else {
      final bytes = await _buildPdf(
        overview: overviewData,
        transactions: rows,
        currency: currency,
        detailed: type == 'detailed',
      );
      await file.writeAsBytes(bytes);
    }

    onProgress?.call(1, 1);
    return file;
  }

  // ---- internals -----------------------------------------------------

  /// (income, expense, transactionCount) — transfers excluded everywhere,
  /// matching report.controller.js's spendMatch.
  Future<(double, double, int)> _totals(
      DatabaseExecutor db, DateTime from, DateTime to) async {
    final rows = await db.rawQuery('''
      SELECT type, COALESCE(SUM(amount), 0) as total, COUNT(*) as cnt FROM transactions
      WHERE date >= ? AND date <= ? AND type IN ('expense', 'income')
      GROUP BY type
    ''', [from.toUtc().toIso8601String(), to.toUtc().toIso8601String()]);

    double income = 0, expense = 0;
    var count = 0;
    for (final r in rows) {
      final total = (r['total'] as num).toDouble();
      count += (r['cnt'] as int);
      if (r['type'] == 'income') income = total;
      if (r['type'] == 'expense') expense = total;
    }
    return (income, expense, count);
  }

  Future<List<CategorySlice>> _categoryBreakdown(
      DatabaseExecutor db, DateTime from, DateTime to, String type) async {
    final rows = await db.rawQuery('''
      SELECT category_id, COALESCE(SUM(amount), 0) as total, COUNT(*) as cnt
      FROM transactions
      WHERE type = ? AND date >= ? AND date <= ?
      GROUP BY category_id
      ORDER BY total DESC
    ''', [type, from.toUtc().toIso8601String(), to.toUtc().toIso8601String()]);

    final grandTotal = rows.fold(0.0, (s, r) => s + (r['total'] as num).toDouble());
    final slices = <CategorySlice>[];

    for (final r in rows) {
      final categoryId = r['category_id'] as String?;
      var name = 'Uncategorised';
      var icon = 'category';
      var color = '#6B7280';
      if (categoryId != null) {
        final catRows = await db.query('categories', where: 'id = ?', whereArgs: [categoryId]);
        if (catRows.isNotEmpty) {
          name = catRows.first['name'] as String;
          icon = catRows.first['icon'] as String;
          color = catRows.first['color'] as String;
        }
      }
      final total = (r['total'] as num).toDouble();
      slices.add(CategorySlice(
        name: name,
        icon: icon,
        color: color,
        total: total,
        count: r['cnt'] as int,
        share: grandTotal > 0 ? total / grandTotal : 0,
        percent: grandTotal > 0 ? ((total / grandTotal) * 100).round() : 0,
      ));
    }
    return slices;
  }

  Future<List<Map<String, dynamic>>> _reportTransactions(
      DatabaseExecutor db, DateTime from, DateTime to) async {
    final rows = await db.rawQuery('''
      SELECT t.*, a.name as account_name, ta.name as to_account_name, c.name as category_name
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN accounts ta ON ta.id = t.to_account_id
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.date >= ? AND t.date <= ?
      ORDER BY t.date DESC
      LIMIT 500
    ''', [from.toUtc().toIso8601String(), to.toUtc().toIso8601String()]);
    return rows;
  }

  String _buildCsv(List<Map<String, dynamic>> rows, String currency) {
    String escape(Object? value) {
      final str = (value ?? '').toString();
      return RegExp(r'[",\n]').hasMatch(str) ? '"${str.replaceAll('"', '""')}"' : str;
    }

    final header = ['Date', 'Type', 'Description', 'Category', 'Account', 'To Account',
      'Amount ($currency)'];
    final lines = [header.map(escape).join(',')];

    for (final r in rows) {
      final date = DateTime.parse(r['date'] as String).toLocal();
      final amount = (r['amount'] as num).toDouble();
      final signed = r['type'] == 'expense' ? -amount : amount;
      lines.add([
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        r['type'],
        r['note'] ?? '',
        r['category_name'] ?? '',
        r['account_name'] ?? '',
        r['to_account_name'] ?? '',
        signed.toStringAsFixed(2),
      ].map(escape).join(','));
    }
    return lines.join('\n');
  }

  Future<List<int>> _buildPdf({
    required ReportOverview overview,
    required List<Map<String, dynamic>> transactions,
    required String currency,
    required bool detailed,
  }) async {
    final doc = pw.Document();
    final forest = PdfColor.fromHex('#00563B');
    final income = PdfColor.fromHex('#16A34A');
    final expense = PdfColor.fromHex('#DC2626');
    final muted = PdfColor.fromHex('#6B7280');

    String money(double v) => '$currency ${v.toStringAsFixed(2)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            color: forest,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('HISAB',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(overview.rangeLabel, style: const pw.TextStyle(color: PdfColors.white)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryTile('Income', money(overview.totals.income), income),
              _summaryTile('Expense', money(overview.totals.expense), expense),
              _summaryTile('Net', money(overview.totals.net),
                  overview.totals.net >= 0 ? income : expense),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Expense by Category',
              style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (overview.expenseByCategory.isEmpty)
            pw.Text('No expenses recorded in this period.',
                style: pw.TextStyle(color: muted, fontSize: 10))
          else
            ...overview.expenseByCategory.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(c.name, style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('${c.percent}%  ${money(c.total)}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                )),
          if (detailed && transactions.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Transactions',
                style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['Date', 'Description', 'Category', 'Account', 'Amount']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(h,
                                style: const pw.TextStyle(
                                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ))
                      .toList(),
                ),
                ...transactions.map((t) {
                  final date = DateTime.parse(t['date'] as String).toLocal();
                  final isTransfer = t['type'] == 'transfer';
                  final amount = (t['amount'] as num).toDouble();
                  final sign = isTransfer ? '' : (t['type'] == 'income' ? '+' : '-');
                  final desc = (t['note'] as String?)?.isNotEmpty == true
                      ? t['note']
                      : (isTransfer
                          ? 'Transfer to ${t['to_account_name'] ?? '—'}'
                          : (t['category_name'] ?? '—'));
                  return pw.TableRow(children: [
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    desc,
                    isTransfer ? 'Transfer' : (t['category_name'] ?? '—'),
                    t['account_name'] ?? '—',
                    '$sign${money(amount)}',
                  ]
                      .map((v) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(v.toString(), style: const pw.TextStyle(fontSize: 8)),
                          ))
                      .toList());
                }),
              ],
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _summaryTile(String label, String value, PdfColor color) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
        width: 150,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      );

  Future<String> _currency(DatabaseExecutor db) async {
    final rows = await db.query('profile', columns: ['currency'], limit: 1);
    return rows.isEmpty ? 'PKR' : (rows.first['currency'] as String? ?? 'PKR');
  }

  String _fmtShort(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
}

final reportPeriodProvider =
    StateProvider<ReportPeriod>((ref) => ReportPeriod.thisMonth);

final reportOverviewProvider = FutureProvider<ReportOverview>((ref) {
  final period = ref.watch(reportPeriodProvider);
  return ref.read(reportRepositoryProvider).overview(period);
});

final reportTrendProvider = FutureProvider<List<TrendPoint>>(
    (ref) => ref.read(reportRepositoryProvider).trend());
