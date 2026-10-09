import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CircleChatLogo extends StatelessWidget {
  final double size;
  final bool withBackground;
  final double borderRadius;

  const CircleChatLogo({
    super.key,
    this.size = 72,
    this.withBackground = true,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: withBackground ? AppTheme.midnightBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: withBackground
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppTheme.mintAccent.withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/icon/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => CustomPaint(
            size: Size(size, size),
            painter: _LogoPainter(),
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Back bubble (pale blue)
    final backPaint = Paint()
      ..color = AppTheme.paleBlue
      ..style = PaintingStyle.fill;

    final backRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.38, h * 0.22, w * 0.40, h * 0.36),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(backRRect, backPaint);

    final backTail = Path()
      ..moveTo(w * 0.68, h * 0.55)
      ..lineTo(w * 0.82, h * 0.64)
      ..lineTo(w * 0.60, h * 0.58)
      ..close();
    canvas.drawPath(backTail, backPaint);

    // 2. Front bubble (mint)
    final frontPaint = Paint()
      ..color = AppTheme.mintAccent
      ..style = PaintingStyle.fill;

    final frontRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.42, w * 0.44, h * 0.36),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(frontRRect, frontPaint);

    final frontTail = Path()
      ..moveTo(w * 0.30, h * 0.75)
      ..lineTo(w * 0.18, h * 0.84)
      ..lineTo(w * 0.40, h * 0.78)
      ..close();
    canvas.drawPath(frontTail, frontPaint);

    // 3. Three charcoal dots
    final dotPaint = Paint()
      ..color = AppTheme.midnightBackground
      ..style = PaintingStyle.fill;

    final dotY = h * 0.60;
    final dotRadius = w * 0.024;
    final centerX = w * 0.44;
    final dotSpacing = w * 0.065;

    for (var offset in [-1, 0, 1]) {
      canvas.drawCircle(Offset(centerX + offset * dotSpacing, dotY), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
