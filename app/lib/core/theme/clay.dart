import 'package:flutter/material.dart';

/// Soft, sparing "clay" depth — used only on the Dashboard's balance card,
/// quick-action icons and FAB, not the whole theme. A dual-tone shadow
/// (light source top-left, soft shadow bottom-right) tinted from the
/// surface's own color, so it reads as puffy rather than a flat fill with a
/// generic drop shadow bolted on.
class Clay {
  Clay._();

  static (Color light, Color dark) _tints(Color base, double delta) {
    final hsl = HSLColor.fromColor(base);
    return (
      hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - delta).clamp(0.0, 1.0)).toColor(),
    );
  }

  /// Dual-tone drop shadow, tinted from [base]. On light backgrounds a
  /// blurred lighter tone reads as a highlight; on dark backgrounds the same
  /// treatment reads as a glowing halo instead, so dark mode leans almost
  /// entirely on the dark side for depth and keeps the highlight minimal.
  static List<BoxShadow> shadows(BuildContext context, Color base,
      {bool small = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (light, dark) = _tints(base, isDark ? 0.10 : 0.16);
    final offset = small ? 4.0 : 7.0;
    final blur = small ? 9.0 : 16.0;
    return [
      BoxShadow(
        color: dark.withOpacity(isDark ? 0.6 : 0.4),
        offset: Offset(offset, offset),
        blurRadius: blur,
      ),
      BoxShadow(
        color: light.withOpacity(isDark ? 0.05 : 0.35),
        offset: Offset(-offset * 0.7, -offset * 0.7),
        blurRadius: blur * (isDark ? 0.5 : 0.85),
      ),
    ];
  }

  static LinearGradient fill(Color base) {
    final (light, dark) = _tints(base, 0.16);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(light, base, 0.5)!, dark],
    );
  }
}
