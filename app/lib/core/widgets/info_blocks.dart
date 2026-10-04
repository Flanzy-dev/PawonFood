import 'package:flutter/material.dart';

import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'food_card.dart';
import 'pills.dart';

/// White bordered tile with a label, a value and a caption (Jarak / Ambil sebelum / Kategori).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.caption});

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
            Text(value, maxLines: 1, style: AppTypography.display(20, weight: 700, height: 26)),
            Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
          ],
        ),
      );
}

/// Sand panel with the struck-through and current price plus the "Bisa ditawar" pill.
class PriceBox extends StatelessWidget {
  const PriceBox({super.key, required this.price, this.originalPrice, this.negotiable = true});

  final int price;
  final int? originalPrice;
  final bool negotiable;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceSand, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (originalPrice != null && price != 0) ...[Text(formatRupiah(originalPrice!), style: struckStyle(15)), const SizedBox(width: 12)],
                    Text(price == 0 ? 'GRATIS' : formatRupiah(price), style: AppTypography.display(34, color: price == 0 ? AppColors.primary : AppColors.ink)),
                  ],
                ),
              ),
            ),
            if (negotiable && price != 0) const Pill('Bisa ditawar', fill: AppColors.surface, color: AppColors.accentInk, height: 32, size: 14, weight: 700, hPad: 14),
          ],
        ),
      );
}
