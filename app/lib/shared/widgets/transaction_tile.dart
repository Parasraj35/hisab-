import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_map.dart';
import '../../features/transactions/data/transaction_model.dart';

/// Shared row used on Dashboard, History and Search results.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.item,
    required this.currency,
    this.onTap,
    this.showDivider = true,
  });

  final TransactionItem item;
  final String currency;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = item.isIncome;
    final accentColor = item.isTransfer
        ? AppColors.info
        : isIncome
            ? context.cIncome
            : context.cExpense;

    final iconData = item.isTransfer
        ? Icons.swap_horiz_rounded
        : iconFromSlug(item.category?.icon);
    final iconColor = item.isTransfer
        ? AppColors.info
        : colorFromHex(item.category?.color, fallback: accentColor);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, size: 19, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium!.copyWith(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${isIncome ? '+' : '-'}${Fmt.plain(item.amount)}',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: accentColor),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: context.cDivider),
      ],
    );
  }
}
