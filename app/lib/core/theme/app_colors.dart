import 'package:flutter/material.dart';

/// Color tokens from DESIGN_SYSTEM.md. Widgets must use these instead of raw hex values.
abstract final class AppColors {
  // Core palette
  static const primary = Color(0xFF2F5D39);
  static const primaryDark = Color(0xFF203D27);
  static const ink = Color(0xFF142319);
  static const inkMuted = Color(0xFF555953);
  static const background = Color(0xFFFAF6ED);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSand = Color(0xFFF3EBDE);
  static const mapSand = Color(0xFFE8DDC9);
  static const border = Color(0xFFE5DED1);
  static const accent = Color(0xFFB15732);
  static const accentInk = Color(0xFF6F2B18);
  static const successTint = Color(0xFFE3EDE4);
  static const cameraBg = Color(0xFF111A15);
  static const foodWarm = Color(0xFFC18A52);
  static const foodGreen = Color(0xFFA8B46A);
  static const error = Color(0xFFB3261E);

  // Sampled from the hi-fi mockups (not in the token list): map details, avatars, camera screens
  static const mapRoad = Color(0xFFF4EEE0);
  static const mapBlock = Color(0xFFDDD1B9);
  static const mapPark = Color(0xFFD5DCB6);
  static const avatarOlive = Color(0xFF6F8A38);
  static const avatarTaupe = Color(0xFF8F7E5C);
  static const cameraControl = Color(0xFF2A3530);
  static const cameraLine = Color(0xFF2E3A33);
  static const detectBox = Color(0xFFCFE3D0);
  static const onGreenMuted = Color(0xFFCFE0D2);
  static const onGreenTrack = Color(0xFF5A8263);
  static const errorLight = Color(0xFFF2B8B5);
  static const cameraText = Color(0xFFD9D3C2);

  /// Soft shadow used on the bottom nav, sheets and the FAB only.
  static const shadow = Color(0x1A142319);
}
