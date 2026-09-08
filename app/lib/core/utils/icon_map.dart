import 'package:flutter/material.dart';

/// Maps the icon slugs the API stores onto Material icons.
/// Keeping this in one place means the backend never ships Flutter constants.
IconData iconFromSlug(String? slug) {
  switch (slug) {
    // Accounts
    case 'payments':
      return Icons.payments_rounded;
    case 'account_balance':
      return Icons.account_balance_rounded;
    case 'account_balance_wallet':
      return Icons.account_balance_wallet_rounded;
    case 'credit_card':
      return Icons.credit_card_rounded;
    // Categories
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'directions_car':
      return Icons.directions_car_rounded;
    case 'bolt':
      return Icons.bolt_rounded;
    case 'shopping_bag':
      return Icons.shopping_bag_rounded;
    case 'favorite':
      return Icons.favorite_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'movie':
      return Icons.movie_rounded;
    case 'laptop':
      return Icons.laptop_mac_rounded;
    case 'storefront':
      return Icons.storefront_rounded;
    case 'card_giftcard':
      return Icons.card_giftcard_rounded;
    case 'add_circle':
      return Icons.add_circle_rounded;
    case 'category':
      return Icons.category_rounded;
    case 'target':
      return Icons.flag_rounded;
    default:
      return Icons.sell_rounded;
  }
}

IconData iconForAccountType(String type) {
  switch (type) {
    case 'bank':
      return Icons.account_balance_rounded;
    case 'wallet':
      return Icons.account_balance_wallet_rounded;
    case 'card':
      return Icons.credit_card_rounded;
    case 'other':
      return Icons.more_horiz_rounded;
    default:
      return Icons.payments_rounded;
  }
}

Color colorFromHex(String? hex, {Color fallback = const Color(0xFF16A34A)}) {
  if (hex == null || hex.isEmpty) return fallback;
  final cleaned = hex.replaceAll('#', '');
  final value =
      int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
  return value == null ? fallback : Color(value);
}
