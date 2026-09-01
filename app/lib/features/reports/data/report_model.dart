class CategorySlice {
  const CategorySlice({
    required this.name,
    required this.icon,
    required this.color,
    required this.total,
    required this.percent,
    required this.share,
    required this.count,
  });

  final String name;
  final String icon;
  final String color;
  final double total;
  final int percent;
  final double share;
  final int count;

  factory CategorySlice.fromJson(Map<String, dynamic> json) => CategorySlice(
        name: (json['name'] ?? 'Uncategorised').toString(),
        icon: (json['icon'] ?? 'category').toString(),
        color: (json['color'] ?? '#6B7280').toString(),
        total: (json['total'] ?? 0).toDouble(),
        percent: (json['percent'] ?? 0) as int,
        share: (json['share'] ?? 0).toDouble(),
        count: (json['count'] ?? 0) as int,
      );
}

class ReportTotals {
  const ReportTotals({
    required this.income,
    required this.expense,
    required this.net,
    required this.transactionCount,
    required this.avgDailySpend,
    required this.savingsRate,
  });

  final double income;
  final double expense;
  final double net;
  final int transactionCount;
  final double avgDailySpend;
  final double savingsRate;

  factory ReportTotals.fromJson(Map<String, dynamic> json) => ReportTotals(
        income: (json['income'] ?? 0).toDouble(),
        expense: (json['expense'] ?? 0).toDouble(),
        net: (json['net'] ?? 0).toDouble(),
        transactionCount: (json['transactionCount'] ?? 0) as int,
        avgDailySpend: (json['avgDailySpend'] ?? 0).toDouble(),
        savingsRate: (json['savingsRate'] ?? 0).toDouble(),
      );
}

class ReportOverview {
  const ReportOverview({
    required this.currency,
    required this.rangeLabel,
    required this.totals,
    required this.expenseByCategory,
    required this.incomeByCategory,
  });

  final String currency;
  final String rangeLabel;
  final ReportTotals totals;
  final List<CategorySlice> expenseByCategory;
  final List<CategorySlice> incomeByCategory;

  factory ReportOverview.fromJson(Map<String, dynamic> json) => ReportOverview(
        currency: (json['currency'] ?? 'PKR').toString(),
        rangeLabel: (json['range']?['label'] ?? '').toString(),
        totals: ReportTotals.fromJson(
            Map<String, dynamic>.from(json['totals'] ?? {})),
        expenseByCategory: (json['expenseByCategory'] as List? ?? [])
            .map((e) => CategorySlice.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        incomeByCategory: (json['incomeByCategory'] as List? ?? [])
            .map((e) => CategorySlice.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final double income;
  final double expense;

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        label: (json['label'] ?? '').toString(),
        income: (json['income'] ?? 0).toDouble(),
        expense: (json['expense'] ?? 0).toDouble(),
      );
}
