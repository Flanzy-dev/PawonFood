import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum InfoTone {
  /// Sand panel (safety notes, privacy, refunds).
  sand,

  /// Success tint (waiting for an answer, good news).
  tint,

  /// Dark toast-like panel (QRIS "belum masuk").
  dark,
}

/// Icon + short note on a soft panel. Used for safety, privacy and status notes across the flows.
class InfoBox extends StatelessWidget {
  const InfoBox(this.text, {super.key, this.icon = LucideIcons.shieldCheck, this.tone = InfoTone.sand, this.title, this.iconColor});

  final String text;
  final String? title;
  final IconData icon;
  final InfoTone tone;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, ic) = switch (tone) {
      InfoTone.sand => (AppColors.surfaceSand, AppColors.ink, AppColors.primary),
      InfoTone.tint => (AppColors.successTint, AppColors.primaryDark, AppColors.primary),
      InfoTone.dark => (AppColors.primaryDark, AppColors.background, AppColors.background),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: tone == InfoTone.tint ? Border.all(color: AppColors.border) : null,
        boxShadow: tone == InfoTone.dark ? const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))] : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 22, color: iconColor ?? ic)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[Text(title!, style: AppTypography.display(17, weight: 700, height: 22, color: fg)), const SizedBox(height: 4)],
                Text(text, style: AppTypography.text(14, height: 21, color: title != null && tone == InfoTone.tint ? AppColors.primary : fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Kemasan" row of the detail and chat cards: wrapped food in the success tint, "Bawa wadah sendiri" in sand with an accent icon.
class PackagingNote extends StatelessWidget {
  const PackagingNote(this.packaging, {super.key, this.compact = false});

  final Packaging packaging;

  /// One line for cards that already say the rest (the hint only for [Packaging.wadahSendiri], the case that needs a reminder).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final wadah = packaging == Packaging.wadahSendiri;
    final icon = wadah ? LucideIcons.container : LucideIcons.package;
    if (compact) {
      return Row(children: [
        Icon(icon, size: 16, color: wadah ? AppColors.accent : AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(wadah ? '${packaging.label} · ${packaging.hint}' : packaging.label, style: AppTypography.text(13, height: 18, weight: 600, color: AppColors.ink))),
      ]);
    }
    return InfoBox(packaging.hint, title: packaging.label, icon: icon, tone: wadah ? InfoTone.sand : InfoTone.tint, iconColor: wadah ? AppColors.accent : null);
  }
}
