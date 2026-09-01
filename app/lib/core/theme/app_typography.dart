import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color primaryText, Color secondaryText) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displaySmall: base.displaySmall!.copyWith(
          fontSize: 32, fontWeight: FontWeight.w700, color: primaryText, letterSpacing: -0.5),
      headlineMedium: base.headlineMedium!.copyWith(
          fontSize: 26, fontWeight: FontWeight.w700, color: primaryText, letterSpacing: -0.3),
      headlineSmall: base.headlineSmall!.copyWith(
          fontSize: 22, fontWeight: FontWeight.w700, color: primaryText),
      titleLarge: base.titleLarge!.copyWith(
          fontSize: 18, fontWeight: FontWeight.w600, color: primaryText),
      titleMedium: base.titleMedium!.copyWith(
          fontSize: 15, fontWeight: FontWeight.w600, color: primaryText),
      bodyLarge: base.bodyLarge!.copyWith(fontSize: 15, color: primaryText),
      bodyMedium: base.bodyMedium!.copyWith(fontSize: 14, color: secondaryText, height: 1.45),
      bodySmall: base.bodySmall!.copyWith(fontSize: 12, color: secondaryText),
      labelLarge: base.labelLarge!.copyWith(
          fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
      labelSmall: base.labelSmall!.copyWith(
          fontSize: 11, fontWeight: FontWeight.w500, color: secondaryText, letterSpacing: 0.2),
    );
  }

  static TextStyle amount(Color color, {double size = 28}) => GoogleFonts.inter(
      fontSize: size, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.5);

  static const TextStyle brand = TextStyle(
      fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2);
}
