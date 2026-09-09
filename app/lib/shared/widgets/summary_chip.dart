import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/clay.dart';
import '../../core/utils/formatters.dart';

/// The paired Income / Expense panels on the dashboard, reused on History and
/// Reports.
///
/// Layout follows the reference: label top-left, arrow in a circle top-right,
/// then the currency code small beside a large amount. Pass `compact: true`
/// where vertical space is tight.
class SummaryChip extends StatelessWidget {
  const SummaryChip({
    super.key,
    required this.label,
    required this.amount,
    required this.currency,
    required this.isIncome,
    this.compact = false,
  });

  final String label;
  final double amount;
  final String currency;
  final bool isIncome;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? context.cIncome : context.cExpense;
    final soft = context.isDark
        ? color.withValues(alpha: 0.14)
        : (isIncome ? AppColors.incomeSoft : AppColors.expenseSoft);

    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        // Flat in dark mode: a shadow tinted from an already-vivid accent
        // reads as a glow against the dark ground rather than depth.
        boxShadow:
            context.isDark ? null : Clay.shadows(context, color, small: true),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isIncome
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: compact ? 13 : 16,
                color: color,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : AppSpacing.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currency,
                  style: TextStyle(
                    fontSize: compact ? 11 : 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  Fmt.plain(amount),
                  style: TextStyle(
                    fontSize: compact ? 15 : 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
