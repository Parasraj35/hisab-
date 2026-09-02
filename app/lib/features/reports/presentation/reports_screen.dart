import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/clay.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/icon_map.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/summary_chip.dart';
import '../data/report_model.dart';
import '../data/report_repository.dart';

/// Screen 17 — Reports
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(reportPeriodProvider);
    final async = ref.watch(reportOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => context.push('/export'),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(reportOverviewProvider),
        ),
        data: (report) => RefreshIndicator(
          color: AppColors.forest,
          onRefresh: () async {
            ref.invalidate(reportOverviewProvider);
            await ref.read(reportOverviewProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 90),
            children: [
              _PeriodSelector(
                period: period,
                onChanged: (p) =>
                    ref.read(reportPeriodProvider.notifier).state = p,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: SummaryChip(
                      label: 'Income',
                      amount: report.totals.income,
                      currency: report.currency,
                      isIncome: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SummaryChip(
                      label: 'Expense',
                      amount: report.totals.expense,
                      currency: report.currency,
                      isIncome: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expense by Category',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.lg),
                    if (report.expenseByCategory.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxl),
                        child: Center(
                          child: Text('No expenses in this period',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                      )
                    else ...[
                      SizedBox(
                        height: 190,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 58,
                                startDegreeOffset: -90,
                                pieTouchData: PieTouchData(
                                  touchCallback: (event, response) {
                                    setState(() {
                                      _touchedIndex = response?.touchedSection
                                              ?.touchedSectionIndex ??
                                          -1;
                                    });
                                  },
                                ),
                                sections: _sections(report.expenseByCategory),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Fmt.currency(report.totals.expense,
                                          code: '', decimals: false)
                                      .trim(),
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: context.cTextPrimary),
                                ),
                                Text('Total',
                                    style:
                                        Theme.of(context).textTheme.labelSmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ...report.expenseByCategory.asMap().entries.map(
                            (entry) => _LegendRow(
                              slice: entry.value,
                              currency: report.currency,
                              highlighted: _touchedIndex == entry.key,
                              showDivider: entry.key <
                                  report.expenseByCategory.length - 1,
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _TrendCard(currency: report.currency),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('At a glance',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    _StatRow(
                      label: 'Net for period',
                      value: Fmt.signed(report.totals.net),
                      color: report.totals.net >= 0
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                    _StatRow(
                      label: 'Average daily spend',
                      value: Fmt.currency(report.totals.avgDailySpend,
                          code: report.currency),
                    ),
                    _StatRow(
                      label: 'Savings rate',
                      value:
                          '${(report.totals.savingsRate * 100).toStringAsFixed(0)}%',
                      color: report.totals.savingsRate >= 0
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                    _StatRow(
                      label: 'Transactions',
                      value: '${report.totals.transactionCount}',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _sections(List<CategorySlice> slices) {
    return slices.asMap().entries.map((entry) {
      final selected = _touchedIndex == entry.key;
      return PieChartSectionData(
        value: entry.value.total,
        color: colorFromHex(entry.value.color),
        radius: selected ? 30 : 24,
        showTitle: false,
      );
    }).toList();
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});

  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('Select period',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ...ReportPeriod.values.map((p) => ListTile(
                    title: Text(p.label),
                    trailing: p == period
                        ? const Icon(Icons.check_circle,
                            color: AppColors.accent, size: 20)
                        : null,
                    onTap: () {
                      onChanged(p);
                      Navigator.pop(sheetContext);
                    },
                  )),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          boxShadow: Clay.shadows(context.cBackground, small: true),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 17, color: context.cTextSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(period.label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: context.cTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.slice,
    required this.currency,
    required this.highlighted,
    required this.showDivider,
  });

  final CategorySlice slice;
  final String currency;
  final bool highlighted;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(slice.color);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          color: highlighted ? color.withOpacity(0.06) : Colors.transparent,
          child: Row(
            children: [
              Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(slice.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text('${slice.percent}%',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 84,
                child: Text(
                  Fmt.currency(slice.total, code: '', decimals: false).trim(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: context.cDivider),
      ],
    );
  }
}

class _TrendCard extends ConsumerWidget {
  const _TrendCard({required this.currency});
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportTrendProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 6 Months', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 150,
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Could not load trend',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              data: (points) {
                if (points.every((p) => p.income == 0 && p.expense == 0)) {
                  return Center(
                    child: Text('Not enough data yet',
                        style: Theme.of(context).textTheme.bodySmall),
                  );
                }

                final maxValue = points.fold<double>(
                  0,
                  (max, p) => [max, p.income, p.expense]
                      .reduce((a, b) => a > b ? a : b),
                );

                return BarChart(
                  BarChartData(
                    maxY: maxValue * 1.15,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(points[index].label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: context.cTextSecondary)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: points.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.income,
                            color: AppColors.accent,
                            width: 7,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          BarChartRodData(
                            toY: entry.value.expense,
                            color: AppColors.expense,
                            width: 7,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _LegendDot(color: AppColors.accent, label: 'Income'),
              const SizedBox(width: AppSpacing.lg),
              _LegendDot(color: AppColors.expense, label: 'Expense'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.color,
    this.isLast = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color ?? context.cTextPrimary)),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: context.cDivider),
      ],
    );
  }
}
