import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/listing.dart';
import '../services/food_label.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'listing_photo.dart';
import 'pills.dart';

/// Struck-through original price.
TextStyle struckStyle(double size) =>
    AppTypography.text(size, color: AppColors.inkMuted).copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.inkMuted);

/// Price in the bottom-right corner of a card: the struck-through original price stacked above the price,
/// right-aligned. Free food shows GRATIS alone.
class CardPrice extends StatelessWidget {
  const CardPrice(this.listing, {super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!l.isFree && l.originalPrice != null) Text(formatRupiah(l.originalPrice!), style: struckStyle(13)),
        if (l.isFree) Text('GRATIS', style: AppTypography.display(22, color: AppColors.primary)) else Text(formatRupiah(l.price), style: AppTypography.display(20, weight: 700)),
      ],
    );
  }
}

/// Food card (DESIGN_SYSTEM.md): photo with a status label and "Sisa N porsi", name, provider, tier tag,
/// distance pill bottom-left and the price block bottom-right.
class FoodCard extends ConsumerWidget {
  const FoodCard({super.key, required this.listing, required this.distance, required this.onTap});

  final Listing listing;
  final double distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = listing;
    final label = foodLabelFor(l, ref.watch(clockProvider)());
    return Semantics(
      button: true,
      label: '${l.name}, ${l.provider.name}, ${l.isFree ? 'gratis' : formatRupiah(l.price)}${l.negotiable ? ', bisa ditawar' : ''}, sisa ${l.portionsLeft} porsi, ${formatDistance(distance)}',
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 134,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    height: 110,
                    child: Stack(
                      children: [
                        Positioned(top: 0, left: 0, child: ListingPhoto(l, width: 104, height: 104, radius: 12)),
                        if (label != null) Positioned(top: 6, right: 6, child: FoodLabelBadge(label)),
                        Positioned(bottom: 12, left: 6, child: StockBadge(l.portionsLeft)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(16, weight: 700, height: 22)),
                              const SizedBox(height: 2),
                              Text(l.provider.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(14, height: 20, color: AppColors.inkMuted)),
                              const SizedBox(height: 4),
                              Align(alignment: Alignment.centerLeft, child: TierTag(l.provider.tier)),
                            ],
                          ),
                        ),
                        Positioned(left: 0, bottom: 0, child: DistancePill(distance)),
                        Positioned(right: 0, bottom: 0, child: CardPrice(l)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
