import 'package:flutter/material.dart';
import 'package:ttmastiff/core/utils/util.dart';

class DashedCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color borderColor;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  const DashedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 12,
    this.color,
    this.borderColor = const Color(0xFFBDBDBD),
    this.dashWidth = 6,
    this.dashGap = 4,
    this.strokeWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Material(
      color: color ?? Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            radius: radius,
            color: borderColor,
            dashWidth: dashWidth,
            dashGap: dashGap,
            strokeWidth: strokeWidth,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  _DashedRRectPainter({
    required this.radius,
    required this.color,
    required this.dashWidth,
    required this.dashGap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final len = (distance + dashWidth).clamp(0, metric.length);
        final segment = metric.extractPath(distance, len.toDouble());
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
