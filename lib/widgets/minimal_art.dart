import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Minimal single-stroke line art for the onboarding screens.
/// Teal strokes on transparent — calm, abstract, no clutter.

class OnboardingArt extends StatelessWidget {
  final int page;

  const OnboardingArt({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: _ArtPainter(page),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  final int page;

  _ArtPainter(this.page);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FourcusColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final c = Offset(size.width / 2, size.height / 2);

    switch (page) {
      case 0:
        _drawFindYourFour(canvas, paint, c);
      case 1:
        _drawProveItDaily(canvas, paint, c);
      default:
        _drawStayFocused(canvas, paint, c);
    }
  }

  /// Four small figures gathered around a shared center (the goal).
  void _drawFindYourFour(Canvas canvas, Paint paint, Offset c) {
    // Shared goal at the center.
    canvas.drawCircle(c, 15, paint);
    canvas.drawCircle(c, 25, paint);
    // Four people around it.
    const radius = 60.0;
    for (var i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * math.pi / 180;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final p = c + dir * radius;
      // Head.
      canvas.drawCircle(p + const Offset(0, -15), 9, paint);
      // Shoulders (arc).
      canvas.drawArc(
        Rect.fromCircle(center: p + const Offset(0, 13), radius: 14),
        math.pi,
        math.pi,
        false,
        paint,
      );
      // Thread connecting each person to the goal.
      canvas.drawLine(p - dir * 22, c + dir * 27, paint);
    }
  }

  /// A rising sun (today) with a check mark (done).
  void _drawProveItDaily(Canvas canvas, Paint paint, Offset c) {
    // Sun.
    canvas.drawCircle(c + const Offset(0, -20), 25, paint);
    // Horizon line.
    canvas.drawLine(
      Offset(c.dx - 68, c.dy + 24),
      Offset(c.dx + 68, c.dy + 24),
      paint,
    );
    // Sun rays.
    for (final dx in [-46.0, -23.0, 0.0, 23.0, 46.0]) {
      canvas.drawLine(
        Offset(c.dx + dx, c.dy - 56),
        Offset(c.dx + dx, c.dy - 66),
        paint,
      );
    }
    // Check mark.
    final check = Path()
      ..moveTo(c.dx - 32, c.dy + 50)
      ..lineTo(c.dx - 11, c.dy + 70)
      ..lineTo(c.dx + 36, c.dy + 20);
    canvas.drawPath(check, paint);
    // Underline.
    canvas.drawLine(
      Offset(c.dx - 38, c.dy + 86),
      Offset(c.dx + 38, c.dy + 86),
      paint,
    );
  }

  /// Concentric focus rings with a steady center dot.
  void _drawStayFocused(Canvas canvas, Paint paint, Offset c) {
    canvas.drawCircle(c, 70, paint);
    canvas.drawCircle(c, 48, paint);
    canvas.drawCircle(c, 27, paint);
    // Center dot (filled).
    canvas.drawCircle(
      c,
      7,
      Paint()
        ..color = FourcusColors.teal
        ..style = PaintingStyle.fill,
    );
    // Small orbiting dot on the outer ring.
    const orbitAngle = -0.6;
    final orbit = Offset(
      c.dx + 70 * math.cos(orbitAngle),
      c.dy + 70 * math.sin(orbitAngle),
    );
    canvas.drawCircle(
      orbit,
      5,
      Paint()
        ..color = FourcusColors.teal
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
