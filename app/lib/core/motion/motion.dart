import 'package:flutter/material.dart';

/// Motion tokens (DESIGN_SYSTEM.md → Motion). Every animation in the app takes its duration and curve from here,
/// and turns itself off when the OS "remove animations" setting is on.
abstract final class Motion {
  /// Finger down: the press-in scale (the release uses [fast], so it reads as the answer).
  static const press = Duration(milliseconds: 100);

  /// Counting numbers up (points, impact tiles).
  static const count = Duration(milliseconds: 700);

  /// Press feedback, small colour changes.
  static const fast = Duration(milliseconds: 150);

  /// Chips, toggles, cards appearing, tab fades.
  static const base = Duration(milliseconds: 220);

  /// Page pushes, sheets, success marks.
  static const slow = Duration(milliseconds: 320);

  /// Delay between items of a staggered list.
  static const stagger = Duration(milliseconds: 40);

  /// Things entering the screen: fast start, soft landing.
  static const enter = Curves.easeOutCubic;

  /// Things leaving the screen.
  static const exit = Curves.easeInCubic;

  /// Things moving between two on-screen positions.
  static const move = Curves.easeInOutCubic;

  /// Small pops only (check marks, a selected map pin). Never for large surfaces.
  static const pop = Curves.easeOutBack;

  /// Success flood (success_flood.dart): green grows out of the check until it covers the screen...
  static const floodGrow = Duration(milliseconds: 520);

  /// ...holds while a large check draws itself...
  static const floodHold = Duration(milliseconds: 400);

  /// ...then shrinks back into the badge (with [exit], so it never slows to a stop).
  static const floodRecede = Duration(milliseconds: 560);

  /// When the flood has settled into the badge (content waiting for it uses this as its delay).
  static const floodLands = Duration(milliseconds: 1480);

  /// Bottom sheets: open with [slow] + [enter], close a bit faster.
  static const sheet = AnimationStyle(duration: slow, reverseDuration: base, curve: enter, reverseCurve: exit);

  /// True when the user asked the OS to remove animations (and in widget tests, see test/support.dart).
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}
