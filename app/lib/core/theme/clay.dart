import 'package:flutter/material.dart';

/// Soft, sparing "clay" depth — used only on the Dashboard's balance card,
/// quick-action icons and FAB, not the whole theme. A dual-tone shadow
/// (light source top-left, soft shadow bottom-right) tinted from the
/// surface's own color, so it reads as puffy rather than a flat fill with a
/// generic drop shadow bolted on.
class Clay {
  Clay._();

  static (Color light, Color dark) _tints(Color base) {
    final hsl = HSLColor.fromColor(base);
    return (
      hsl.withLightness((hsl.lightness + 0.16).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0)).toColor(),
    );
  }

  static List<BoxShadow> shadows(Color base, {bool small = false}) {
    final (light, dark) = _tints(base);
    final offset = small ? 4.0 : 7.0;
    final blur = small ? 9.0 : 16.0;
    return [
      BoxShadow(
          color: dark.withOpacity(0.4),
          offset: Offset(offset, offset),
          blurRadius: blur),
      BoxShadow(
        color: light.withOpacity(0.35),
        offset: Offset(-offset * 0.7, -offset * 0.7),
        blurRadius: blur * 0.85,
      ),
    ];
  }

  static LinearGradient fill(Color base) {
    final (light, dark) = _tints(base);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(light, base, 0.5)!, dark],
    );
  }
}
