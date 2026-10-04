import 'package:flutter/material.dart';

/// 4/8 spacing system and radius tokens from DESIGN_SYSTEM.md.
abstract final class AppSpacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;
  static const s64 = 64.0;

  /// Screen side padding.
  static const screen = 16.0;
  static const minTouch = 44.0;
}

abstract final class AppRadius {
  static const badge = 8.0;
  static const thumb = 12.0;
  static const card = 16.0;
  static const cardLarge = 20.0;
  static const sheet = 28.0;
  static const full = 999.0;

  static BorderRadius circular(double r) => BorderRadius.circular(r);
}
