import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data/settings_repository.dart';
import '../../core/motion/pressable.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Round radius indicator on the map (B12c): the circle looks like the radius ring itself (tinted fill, dashed outline)
/// with the radius inside, number over unit ("1" over "km"). Tap opens the radius picker.
class RadiusIndicator extends StatelessWidget {
  const RadiusIndicator({super.key, required this.meters, required this.onTap});

  final double meters;
  final VoidCallback onTap;

  static const size = 48.0;

  /// `(1, km)`, `(1,5, km)`, `(500, m)`.
  static (String, String) parts(double meters) {
    final label = formatRadius(meters).split(' ');
    return (label.first, label.last);
  }

  @override
  Widget build(BuildContext context) {
    final (number, unit) = parts(meters);
    return Semantics(
      button: true,
      label: 'Radius ${formatRadius(meters)}, ketuk untuk mengubah',
      excludeSemantics: true,
      child: Pressable(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.successTint,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: CustomPaint(
                painter: _DashedRing(),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(number, style: AppTypography.display(number.length > 2 ? 15 : 20, weight: 800, height: number.length > 2 ? 17 : 22, color: AppColors.primaryDark)),
                          Text(unit, style: AppTypography.text(11, weight: 600, height: 12, color: AppColors.primaryDark)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed circle outline, the same 7 on / 6 off pattern and 2.5 stroke as the radius ring on the map.
class _DashedRing extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.primaryDark;
    final path = Path()..addOval((Offset.zero & size).deflate(1.25));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 13) {
        canvas.drawPath(m.extractPath(d, math.min(d + 7, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
