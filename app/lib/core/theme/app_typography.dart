import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale from DESIGN_SYSTEM.md. Headings use Bricolage Grotesque, UI text uses Inter.
/// Both are variable fonts, so weight is set through [FontVariation].
abstract final class AppTypography {
  static const _display = 'BricolageGrotesque';
  static const _ui = 'Inter';

  static FontWeight _fw(double w) => FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

  /// Display / heading style. [height] is the line height in logical pixels.
  static TextStyle display(double size, {double weight = 800, double? height, Color color = AppColors.ink}) => TextStyle(
        fontFamily: _display,
        fontSize: size,
        fontWeight: _fw(weight),
        fontVariations: [FontVariation('wght', weight), const FontVariation('opsz', 14)],
        letterSpacing: -size * 0.03,
        height: height == null ? null : height / size,
        color: color,
      );

  /// UI / body style (Inter).
  static TextStyle text(double size, {double weight = 400, double? height, Color color = AppColors.ink, double? letterSpacing}) => TextStyle(
        fontFamily: _ui,
        fontSize: size,
        fontWeight: _fw(weight),
        fontVariations: [FontVariation('wght', weight)],
        height: height == null ? null : height / size,
        color: color,
        letterSpacing: letterSpacing,
      );

  // Named tokens (size / line height, see the scale table in DESIGN_SYSTEM.md)
  static TextStyle get titleXl => display(28, height: 34);
  static TextStyle get titleL => display(22, weight: 700, height: 28);
  static TextStyle get titleM => display(18, weight: 700, height: 24);
  static TextStyle get body => text(15, height: 22);
  static TextStyle get bodyMuted => text(15, height: 22, color: AppColors.inkMuted);
  static TextStyle get label => text(14, weight: 600, height: 18);
  static TextStyle get caption => text(12, height: 16, color: AppColors.inkMuted);
}
