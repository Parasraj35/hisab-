import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Onboarding illustrations — vector compositions echoing the mockup's
/// wallet-and-coins artwork. Swap for `Image.asset(...)` when the real
/// illustrations arrive; the slide list already keys off an index.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({super.key, required this.index, this.size = 220});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.incomeSoft,
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.58, size * 0.58),
          painter: switch (index) {
            1 => _ChartPainter(),
            2 => _GoalPainter(),
            _ => _WalletCoinsPainter(),
          },
        ),
      ),
    );
  }
}

/// Slide 1 — wallet with coins stacked beside it.
class _WalletCoinsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = AppColors.forest;
    final accent = Paint()..color = AppColors.accent;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.30, w * 0.72, h * 0.52),
        Radius.circular(w * 0.09),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.44, h * 0.46, w * 0.34, h * 0.19),
        Radius.circular(w * 0.05),
      ),
      accent,
    );

    // Coin stack
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromLTWH(w * 0.70, h * (0.70 - i * 0.14), w * 0.30, h * 0.14),
        i.isEven ? accent : fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slide 2 — bar chart showing where money goes.
class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const heights = [0.38, 0.62, 0.46, 0.86];
    final barWidth = w * 0.16;

    for (var i = 0; i < heights.length; i++) {
      final barHeight = h * heights[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (w * 0.23), h - barHeight, barWidth, barHeight),
          Radius.circular(barWidth * 0.35),
        ),
        Paint()..color = i.isEven ? AppColors.forest : AppColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slide 3 — savings goal ring.
class _GoalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final centre = Offset(w / 2, h / 2);
    final radius = w * 0.40;
    final stroke = w * 0.14;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = AppColors.accent.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -1.5708,
      4.4, // ~70% of the ring
      false,
      Paint()
        ..color = AppColors.forest
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(centre, w * 0.11, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
