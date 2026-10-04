import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/conversation.dart';
import '../models/enums.dart';
import '../services/food_label.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Generic rounded pill. Badges, distance, points and status are presets below.
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.fill = AppColors.surfaceSand,
    this.color = AppColors.ink,
    this.border,
    this.icon,
    this.iconColor,
    this.height = 28,
    this.size = 12,
    this.weight = 600,
    this.hPad = 12,
  });

  final String label;
  final Color fill;
  final Color color;
  final Color? border;
  final IconData? icon;
  final Color? iconColor;
  final double height;
  final double size;
  final double weight;
  final double hPad;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999), border: border == null ? null : Border.all(color: border!)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: size + 3, color: iconColor ?? color), const SizedBox(width: 4)],
            Text(label, maxLines: 1, style: AppTypography.text(size, weight: weight, color: color)),
          ],
        ),
      );
}

/// Status label on food photos: Populer / Terbaru / Hampir habis.
class FoodLabelBadge extends StatelessWidget {
  const FoodLabelBadge(this.label, {super.key});

  final FoodLabel label;

  @override
  Widget build(BuildContext context) => Pill(label.label, fill: AppColors.surface, height: 24, weight: 700, hPad: 8);
}

/// Terracotta "Sisa N porsi" badge.
class StockBadge extends StatelessWidget {
  const StockBadge(this.portions, {super.key, this.height = 24, this.size = 12});

  final int portions;
  final double height;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Pill('Sisa $portions porsi', fill: AppColors.accent, color: AppColors.background, height: height, size: size, weight: 700, hPad: 8);
}

/// Small label on a success tint (tier names, reward category, validity).
class InfoTag extends StatelessWidget {
  const InfoTag(this.label, {super.key, this.height = 24, this.size = 12});

  final String label;
  final double height;
  final double size;

  @override
  Widget build(BuildContext context) => IntrinsicWidth(
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: AppTypography.text(size, weight: 600, color: AppColors.primary)),
        ),
      );
}

/// Tier tag (Sobat Pawon / Food Savior / Pahlawan Pangan).
class TierTag extends InfoTag {
  TierTag(Tier tier, {super.key, super.height, super.size}) : super(tier.label);
}

class DistancePill extends StatelessWidget {
  const DistancePill(this.meters, {super.key});

  final double meters;

  @override
  Widget build(BuildContext context) => Pill(formatDistance(meters), size: 12, hPad: 10);
}

class PointsPill extends StatelessWidget {
  const PointsPill(this.points, {super.key});

  final int points;

  @override
  Widget build(BuildContext context) => Pill(
        '$points Poin',
        fill: AppColors.surfaceSand,
        color: AppColors.accentInk,
        icon: LucideIcons.coins,
        iconColor: AppColors.accent,
        height: 40,
        size: 15,
        weight: 700,
        hPad: 16,
      );
}

/// Status label on a thread row: Tawaran diterima / Siap diambil / Habis.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final ThreadStatus status;

  @override
  Widget build(BuildContext context) {
    final muted = status == ThreadStatus.soldOut || status == ThreadStatus.waiting;
    return Pill(
      status.label,
      fill: muted ? AppColors.surfaceSand : AppColors.successTint,
      color: muted ? AppColors.inkMuted : AppColors.primary,
      hPad: 10,
    );
  }
}
