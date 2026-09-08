import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// Flat bottom bar with an active underline, shared by Dashboard, Accounts,
/// Reports and Settings.
///
/// The notch was removed to match the reference: the FAB floats above the bar
/// rather than being cut into it.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _destinations = [
    (icon: Icons.home_rounded, label: 'Home', route: '/dashboard'),
    (
      icon: Icons.account_balance_wallet_outlined,
      label: 'Accounts',
      route: '/accounts'
    ),
    (icon: Icons.bar_chart_rounded, label: 'Reports', route: '/reports'),
    (icon: Icons.menu_rounded, label: 'More', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget item(int index) {
      final dest = _destinations[index];
      final active = currentIndex == index;
      final color = active ? context.cPrimary : context.cTextTertiary;

      return Expanded(
        child: InkWell(
          onTap: () => context.go(dest.route),
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(dest.icon, size: 23, color: color),
                const SizedBox(height: 4),
                Text(
                  dest.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                // Underline marks the active tab; a transparent bar keeps every
                // item the same height so nothing shifts when you switch tabs.
                Container(
                  height: 3,
                  width: 22,
                  decoration: BoxDecoration(
                    color: active ? context.cPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        border: Border(top: BorderSide(color: context.cDivider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              item(0),
              item(1),
              // Space reserved for the floating FAB.
              const SizedBox(width: 68),
              item(2),
              item(3),
            ],
          ),
        ),
      ),
    );
  }
}
