import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/listing.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'food_card.dart';
import 'listing_photo.dart';

/// Compact food card for the map sheet (112 tall): photo, name, "Toko · sisa N porsi · s/d HH.MM", walking
/// distance bottom-left and the price block bottom-right. The whole card is the tap target (no button).
class MiniFoodCard extends StatelessWidget {
  const MiniFoodCard({super.key, required this.listing, required this.distance, required this.onTap});

  final Listing listing;
  final double distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Semantics(
      button: true,
      label: '${l.name}, ${l.provider.name}, ${l.isFree ? 'gratis' : formatRupiah(l.price)}, sisa ${l.portionsLeft} porsi, ${formatDistance(distance)}, ${walkLabel(distance)}',
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 112,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListingPhoto(l, width: 88, height: 88, radius: 12),
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
                              Text('${l.provider.name} · sisa ${l.portionsLeft} porsi · s/d ${formatTime(l.pickupBy)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(12, height: 18, color: AppColors.inkMuted)),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.personStanding, size: 20, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text('${formatDistance(distance)} · ± ${walkMinutes(distance)} mnt', style: AppTypography.text(14, weight: 500)),
                            ],
                          ),
                        ),
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
