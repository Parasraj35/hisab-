import 'package:flutter/widgets.dart';

class Validators {
  Validators._();

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok =
        RegExp(r'^[\w\.\-\+]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? Function(String?) confirmPassword(
          TextEditingController original) =>
      (v) {
        if (v == null || v.isEmpty) return 'Confirm your password';
        return v == original.text ? null : 'Passwords do not match';
      };

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    return RegExp(r'^\+?[0-9\s\-]{7,15}$').hasMatch(v.trim())
        ? null
        : 'Enter a valid phone number';
  }

  static String? amount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Amount is required';
    final parsed = double.tryParse(v.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than zero';
    return null;
  }
}
