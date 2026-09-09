import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// HISAB logo — the rounded-square wallet mark from the splash screen,
/// drawn as vector geometry so it stays crisp at any size and ships with
/// no asset files.
///
/// Replace with `Image.asset(...)` once the official artwork is supplied;
/// nothing else in the app needs to change.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96, this.radius = 26});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.56, size * 0.56),
          painter: _WalletPainter(),
        ),
      ),
    );
  }
}

class _WalletPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.115;

    final outline = Paint()
      ..color = AppColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;

    // Wallet body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(stroke / 2, h * 0.18, w - stroke, h * 0.64),
      Radius.circular(w * 0.16),
    );
    canvas.drawRRect(body, outline);

    // Card slot on the right edge
    final slot = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.58, h * 0.40, w * 0.42, h * 0.22),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
      slot,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.fill,
    );

    // Clasp dot
    canvas.drawCircle(
      Offset(w * 0.74, h * 0.51),
      w * 0.055,
      Paint()..color = AppColors.forest,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
