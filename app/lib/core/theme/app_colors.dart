import 'package:flutter/material.dart';

/// Design tokens taken directly from the HISAB mockup sheet.
class AppColors {
  AppColors._();

  // Brand greens — exact values supplied by the client
  static const Color forest =
      Color(0xFF00563B); // buttons, active states, brand icons
  static const Color forestDeep = Color(0xFF00563B); // splash background
  static const Color primary = Color(0xFF00563B); // filled buttons
  static const Color primaryPressed =
      Color(0xFF00432E); // 12% darker, for press state
  static const Color header =
      Color(0xFF004325); // app bars + the dashboard balance card
  static const Color accent = Color(0xFF008F68); // FAB, positive accents

  // Semantic
  static const Color income = Color(0xFF22A447);
  static const Color incomeSoft = Color(0xFFE8F5EF); // "Light Green"
  static const Color expense = Color(0xFFE53935);
  static const Color expenseSoft = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Neutrals (light)
  static const Color background = Color(0xFFF7F8F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9FAFB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFEEF0EF);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Dark mode — client-supplied palette (screen 28)
  static const Color darkBackground = Color(0xFF07100D);
  static const Color darkHeader = Color(0xFF00563B);
  static const Color darkSurface = Color(0xFF18201D);
  static const Color darkSurfaceAlt = Color(0xFF222A27);
  static const Color darkPrimary = Color(0xFF00A878);
  static const Color darkLightGreen = Color(0xFFD9F5EA);
  static const Color darkBorder = Color(0xFF303936);
  static const Color darkTextPrimary = Color(0xFFF5F7F6);
  static const Color darkTextSecondary = Color(0xFFA8B2AE);
  static const Color darkIncome = Color(0xFF32C96B);
  static const Color darkExpense = Color(0xFFFF5C5C);
  static const Color darkWarning = Color(0xFFF5B942);
  static const Color darkIconMuted = Color(0xFF7F8C87);

  // Quick Action tiles (dashboard). Add Expense / Add Income reuse the app's
  // own semantic red/green — the same colours every amount in the app already
  // uses — so the tint carries real meaning instead of being four arbitrary
  // decorative hues. Transfer and More aren't income or expense, so they get
  // one neutral tone rather than inventing two more colours to fill the row.
  static const Color quickNeutral = Color(0xFF4B5563);
  static const Color quickNeutralSoft = Color(0xFFEEF0EF);

  static const List<Color> categoryPalette = [
    Color(0xFFF97316),
    Color(0xFF3B82F6),
    Color(0xFFEAB308),
    Color(0xFFA855F7),
    Color(0xFFEF4444),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFF6B7280),
  ];
}

/// Theme-aware palette.
///
/// `AppColors` values are compile-time constants, so they can't change with
/// brightness. These getters resolve against the active theme instead, which
/// is what makes screen 28 (dark mode) actually work across every screen.
extension AppPalette on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cBackground =>
      isDark ? AppColors.darkBackground : AppColors.background;
  Color get cBorder => isDark ? AppColors.darkBorder : AppColors.border;
  Color get cDivider => isDark ? AppColors.darkBorder : AppColors.divider;
  Color get cSurface => isDark ? AppColors.darkSurface : AppColors.surface;
  Color get cSurfaceAlt =>
      isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
  Color get cTextPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get cTextSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get cTextTertiary =>
      isDark ? AppColors.darkIconMuted : AppColors.textTertiary;
  Color get cIconMuted =>
      isDark ? AppColors.darkIconMuted : AppColors.textTertiary;

  Color get cPrimary => isDark ? AppColors.darkPrimary : AppColors.primary;
  Color get cHeader => isDark ? AppColors.darkHeader : AppColors.header;
  Color get cAccent => isDark ? AppColors.darkPrimary : AppColors.accent;
  Color get cLightGreen =>
      isDark ? AppColors.darkLightGreen : AppColors.incomeSoft;

  Color get cIncome => isDark ? AppColors.darkIncome : AppColors.income;
  Color get cExpense => isDark ? AppColors.darkExpense : AppColors.expense;
  Color get cWarning => isDark ? AppColors.darkWarning : AppColors.warning;

  /// Quick Action tile fill. In dark mode the pastel background is replaced
  /// with a low-opacity wash of the icon colour so it doesn't glow.
  Color quickTint(Color base, Color softLight) =>
      isDark ? base.withValues(alpha: 0.16) : softLight;
}
