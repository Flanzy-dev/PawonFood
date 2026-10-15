import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/motion.dart';
import '../motion/pressable.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'brand.dart';

/// Circular 44pt icon button (back, close, flash, locate...).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.fill = AppColors.surface,
    this.borderColor = AppColors.border,
    this.iconColor = AppColors.ink,
    this.size = 44,
    this.shadow = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  final Color fill;
  final Color? borderColor;
  final Color iconColor;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticLabel,
        child: Pressable(
          enabled: onTap != null,
          scale: 0.92,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: shadow ? const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))] : null),
            child: Material(
              color: fill,
              shape: CircleBorder(side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: SizedBox(width: size, height: size, child: Icon(icon, size: 24, color: iconColor))),
            ),
          ),
        ),
      );
}

/// "Langkah N dari 3" progress: 3 segments, green when done, sand when pending.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, this.total = 3, this.dark = false});

  final int current;
  final int total;
  final bool dark;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Langkah $current dari $total',
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < current ? (dark ? AppColors.background : AppColors.primary) : (dark ? AppColors.cameraLine : AppColors.border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

/// Height of the bar above the system gesture inset: icon + label plus a little air, so the bar sits close to the
/// gesture line instead of leaving dead space under the labels.
const double navBarHeight = 68;
const double _fabRise = 30;

/// How far the raised Bagikan button sticks out above the bar (floating map cards stay clear of it).
const double navFabRise = _fabRise;

/// Bottom space a tab screen should leave so content is not hidden behind the nav bar.
double navContentInset(BuildContext context) => navBarHeight + MediaQuery.paddingOf(context).bottom + 16;

/// Bottom navigation: Beranda, Peta, **Bagikan** (raised green FAB with the logo), Pesan, Profil.
class PawonBottomNav extends StatelessWidget {
  const PawonBottomNav({super.key, required this.currentIndex, required this.onTap, required this.onShare});

  /// Index among the four tabs: 0 Beranda, 1 Peta, 2 Pesan, 3 Profil.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onShare;

  static const _items = [
    (LucideIcons.house, 'Beranda'),
    (LucideIcons.map, 'Peta'),
    (LucideIcons.messageSquare, 'Pesan'),
    (LucideIcons.user, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    Widget item(int i) {
      final (icon, label) = _items[i];
      final on = i == currentIndex;
      final color = on ? AppColors.primary : AppColors.inkMuted;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          child: InkResponse(
            onTap: () => onTap(i),
            radius: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(children: [
                // The active icon takes the green; the change eases instead of snapping. No bounce: tabs are tapped all day.
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: Motion.of(context, Motion.base),
                  builder: (_, c, _) => Icon(icon, size: 24, color: c),
                ),
                const SizedBox(height: 4),
                // Tab labels stop growing at 1.3x: the bar is a fixed 68 dp and a 2x label would overflow it.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: AnimatedDefaultTextStyle(
                    duration: Motion.of(context, Motion.base),
                    style: AppTypography.text(12, weight: on ? 700 : 500, color: color),
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    // The widget is 30pt taller than the bar so the raised FAB stays inside its bounds (taps outside a
    // widget's bounds are not delivered). Empty areas around the FAB let taps through to the content below.
    return SizedBox(
      height: navBarHeight + inset + _fabRise,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: _fabRise,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, -4))],
              ),
              padding: EdgeInsets.only(bottom: inset),
              child: Row(children: [
                item(0),
                item(1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(children: [
                      const SizedBox(height: 24),
                      const SizedBox(height: 4),
                      // The FAB above already says "Bagikan makanan" to screen readers; this caption is only a visual label.
                      ExcludeSemantics(
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: Text('Bagikan', maxLines: 1, style: AppTypography.text(12, weight: 700, color: AppColors.primary)),
                        ),
                      ),
                    ]),
                  ),
                ),
                item(2),
                item(3),
              ]),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                button: true,
                label: 'Bagikan makanan',
                child: GestureDetector(
                  onTap: onShare,
                  child: Pressable(
                    scale: 0.92,
                    child: Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, -2))]),
                      child: Container(
                        width: 62,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const PawonLogo(size: 36, color: AppColors.background),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
