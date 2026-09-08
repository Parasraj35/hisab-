import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_map.dart';
import '../../features/accounts/data/account_model.dart';

class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    this.onTap,
    this.trailing,
    this.showDivider = true,
    this.dense = false,
  });

  final Account account;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDivider;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromHex(account.color, fallback: AppColors.forest);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: dense ? AppSpacing.sm : AppSpacing.md),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconForAccountType(account.type),
                      size: 19, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(account.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium!
                                    .copyWith(fontSize: 14)),
                          ),
                          if (account.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.cLightGreen,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Default',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: context.isDark
                                          ? AppColors.darkHeader
                                          : AppColors.forest)),
                            ),
                          ],
                        ],
                      ),
                      if (!dense) ...[
                        const SizedBox(height: 2),
                        Text(account.type.toUpperCase(),
                            style: theme.textTheme.labelSmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                trailing ??
                    Text(
                      Fmt.currency(account.currentBalance,
                          code: account.currency),
                      style:
                          theme.textTheme.titleMedium!.copyWith(fontSize: 13),
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
