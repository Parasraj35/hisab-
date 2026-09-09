import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.itemLabel,
    this.itemLeading,
    this.hint,
    this.validator,
  });

  final String label;
  final List<T> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String Function(T) itemLabel;
  final Widget Function(T)? itemLeading;
  final String? hint;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: context.cTextSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          validator: validator,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: context.cTextSecondary),
          hint: hint == null ? null : Text(hint!),
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Row(
                      children: [
                        if (itemLeading != null) ...[
                          itemLeading!(item),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        Flexible(
                          child: Text(itemLabel(item),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
