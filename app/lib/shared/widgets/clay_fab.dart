import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/clay.dart';
import 'pressable.dart';

/// The app's floating add button — a puffy clay circle instead of a flat
/// Material FAB, reused wherever a screen needs the same "+" action
/// (Dashboard, Accounts, ...).
class ClayFab extends StatelessWidget {
  const ClayFab({super.key, required this.onTap, this.icon = Icons.add});

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = context.cAccent;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          gradient: Clay.fill(color),
          shape: BoxShape.circle,
          boxShadow: Clay.shadows(context, color),
        ),
        child: Icon(icon, size: 28, color: Colors.white),
      ),
    );
  }
}
