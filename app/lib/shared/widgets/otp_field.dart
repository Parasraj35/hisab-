import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Six read-only boxes driven by an external code string (screen 4).
class OtpBoxes extends StatelessWidget {
  const OtpBoxes(
      {super.key, required this.code, this.length = 6, this.hasError = false});

  final String code;
  final int length;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final filled = i < code.length;
        final isActive = i == code.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          height: 52,
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasError
                  ? context.cExpense
                  : isActive
                      ? context.cPrimary
                      : context.cBorder,
              width: isActive || hasError ? 1.6 : 1,
            ),
          ),
          child: Text(
            filled ? code[i] : '',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.cTextPrimary),
          ),
        );
      }),
    );
  }
}

/// Custom numeric keypad matching the mockup (keeps the OS keyboard off-screen).
class NumericKeypad extends StatelessWidget {
  const NumericKeypad(
      {super.key, required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Material(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.cBorder),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );

    Widget digit(String d) => key(
          Text(d,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: context.cTextPrimary)),
          () => onDigit(d),
        );

    return Column(
      children: [
        Row(children: [digit('1'), digit('2'), digit('3')]),
        Row(children: [digit('4'), digit('5'), digit('6')]),
        Row(children: [digit('7'), digit('8'), digit('9')]),
        Row(children: [
          const Expanded(child: SizedBox(height: 54)),
          digit('0'),
          key(
              Icon(Icons.backspace_outlined,
                  size: 20, color: context.cTextSecondary),
              onBackspace),
        ]),
      ],
    );
  }
}
