import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/clay.dart';

/// Shared row for Settings, Security and Profile (screens 21–23).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Tints the icon's chip background — a different color per row reads far
  /// more scannable than every row sharing the same monochrome icon.
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.cExpense : context.cTextPrimary;
    final chipColor =
        danger ? context.cExpense : (iconColor ?? context.cPrimary);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: chipColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: chipColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: color)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    (onTap != null
                        ? Icon(Icons.keyboard_arrow_right_rounded,
                            color: context.cTextTertiary)
                        : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: context.cDivider),
      ],
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(title.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall!
                  .copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: Clay.shadows(context, context.cBackground, small: true),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
