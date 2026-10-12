import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/motion.dart';
import '../motion/pressable.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// What sits at the start of an [OptionRow].
enum OptionLead {
  /// A radio dot (single choice: radius, category, payment method).
  radio,

  /// [OptionRow.icon] in a tinted circle (pickup points, "Pilih lokasi di peta").
  badge,

  /// [OptionRow.icon] on its own (locations).
  icon,

  /// Nothing.
  none,
}

/// Bordered choice row used in sheets and forms (B5c Ganti lokasi, C15b titik ambil, C15c kategori, D18g radius,
/// B10d cara bayar). Selected rows take the success tint and a green outline; the change animates.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.lead = OptionLead.radio,
    this.icon = LucideIcons.mapPin,
    this.tag,
    this.showCheck = false,
    this.chevron = false,
    this.enabled = true,
    this.trailingIcon,
    this.trailingLabel,
    this.onTrailing,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final OptionLead lead;
  final IconData icon;

  /// Small dark-green pill on the right ("Utama", "Disarankan", "Dari peta").
  final String? tag;

  /// Check mark on the right when selected (instead of a radio dot).
  final bool showCheck;
  final bool chevron;
  final bool enabled;

  /// A second action on the right, in place of the chevron (the ✕ on an applied voucher). [trailingLabel] names it
  /// for screen readers, which reach it as a custom action on the row.
  final IconData? trailingIcon;
  final String? trailingLabel;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, Motion.base);
    final muted = !enabled;
    final trailing = trailingIcon != null && onTrailing != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: [title, ?subtitle, ?tag].join(', '),
      // excludeSemantics drops the InkWell's own tap action, so the row has to expose it here.
      onTap: enabled ? onTap : null,
      customSemanticsActions: trailing && enabled ? {CustomSemanticsAction(label: trailingLabel ?? ''): onTrailing!} : null,
      excludeSemantics: true,
      child: Pressable(
        enabled: enabled && onTap != null,
        scale: 0.98,
        child: AnimatedContainer(
          duration: d,
          curve: Motion.move,
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: selected ? AppColors.successTint : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    switch (lead) {
                      OptionLead.radio => _RadioDot(on: selected, duration: d),
                      OptionLead.badge => Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: selected ? AppColors.surface : AppColors.surfaceSand, shape: BoxShape.circle),
                          child: Icon(icon, size: 22, color: AppColors.primary),
                        ),
                      OptionLead.icon => Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.inkMuted),
                      OptionLead.none => const SizedBox.shrink(),
                    },
                    if (lead != OptionLead.none) const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, style: AppTypography.display(16, weight: 700, height: 22, color: muted ? AppColors.inkMuted : AppColors.ink)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
                          ],
                        ],
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        // Dark on the selected row, a soft tint elsewhere ("Utama" on an unselected point).
                        decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.successTint, borderRadius: BorderRadius.circular(999)),
                        child: Text(tag!, style: AppTypography.text(12, weight: 700, color: selected ? AppColors.background : AppColors.primary)),
                      ),
                    ],
                    if (showCheck) ...[
                      const SizedBox(width: 12),
                      AnimatedScale(
                        scale: selected ? 1 : 0.5,
                        duration: d,
                        curve: selected ? Motion.pop : Motion.exit,
                        child: AnimatedOpacity(
                          opacity: selected ? 1 : 0,
                          duration: d,
                          child: const Icon(LucideIcons.check, size: 22, color: AppColors.primary),
                        ),
                      ),
                    ],
                    if (trailing)
                      // The row's padding leaves 16 dp on the right; the 44 dp target eats 11 of it so the icon lines up with a chevron.
                      Transform.translate(
                        offset: const Offset(11, 0),
                        child: InkResponse(
                          onTap: enabled ? onTrailing : null,
                          radius: 22,
                          child: SizedBox.square(dimension: 44, child: Icon(trailingIcon, size: 22, color: AppColors.inkMuted)),
                        ),
                      )
                    else if (chevron) ...[const SizedBox(width: 8), const Icon(LucideIcons.chevronRight, size: 22, color: AppColors.ink)],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.on, required this.duration});

  final bool on;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: duration,
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: on ? AppColors.primary : AppColors.borderStrong, width: on ? 2 : 1.5),
        ),
        child: AnimatedScale(
          scale: on ? 1 : 0.5,
          duration: duration,
          curve: on ? Motion.pop : Motion.exit,
          child: AnimatedOpacity(
            opacity: on ? 1 : 0,
            duration: duration,
            child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          ),
        ),
      );
}
