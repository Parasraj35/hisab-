import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: context.cPrimary)),
          ),
      ],
    );
  }
}
