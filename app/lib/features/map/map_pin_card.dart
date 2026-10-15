import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/listing.dart';
import '../../core/motion/pressable.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/food_card.dart';
import '../../core/widgets/listing_photo.dart';

/// B12c floating product card: 170 tall with a 104 px photo (as big as the Beranda food card photo), name, "Penyedia ·
/// sisa N porsi · s/d HH.MM", walking distance bottom-left and the price block bottom-right. Shown when a price pin is tapped,
/// in place of the bottom sheet. The whole card opens the listing; ✕ closes it.
class MapPinCard extends StatelessWidget {
  const MapPinCard({super.key, required this.listing, required this.distance, required this.onTap, required this.onClose});

  final Listing listing;
  final double distance;
  final VoidCallback onTap;
  final VoidCallback onClose;

  /// Card height at normal text size (it grows with the system text size).
  static const height = 170.0;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Semantics(
      container: true,
      label: '${l.name}, ${l.provider.name}, ${l.isFree ? 'gratis' : formatRupiah(l.price)}, sisa ${l.portionsLeft} porsi, ${formatDistance(distance)}, ${walkLabel(distance)}',
      child: Pressable(
        scale: 0.98,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: math.max(height, 142 * textScaleOf(context) + 28),
            child: Stack(
              children: [
                Positioned.fill(child: InkWell(onTap: onTap)),
                Positioned(left: 14, top: 14, child: IgnorePointer(child: ListingPhoto(l, width: 104, height: 104, radius: 14))),
                Positioned(
                  left: 130,
                  top: 14,
                  right: 14,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Room for the ✕ in the top-right corner: the name wraps to two lines before it.
                        Padding(
                          padding: const EdgeInsets.only(right: 36),
                          child: Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.display(17, weight: 700, height: 22)),
                        ),
                        const SizedBox(height: 2),
                        Text('${l.provider.name} · sisa ${l.portionsLeft} porsi · s/d ${formatTime(l.pickupBy)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.text(12, height: 18, color: AppColors.inkMuted)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 18,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.personStanding, size: 24, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('${formatDistance(distance)} · ${walkLabel(distance)}', style: AppTypography.text(14, weight: 500)),
                      ],
                    ),
                  ),
                ),
                Positioned(right: 14, bottom: 19, child: IgnorePointer(child: CardPrice(l, priceSize: 22))),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Semantics(
                    container: true,
                    button: true,
                    label: 'Tutup kartu',
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: onClose,
                      radius: 22,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(child: DecoratedBox(decoration: BoxDecoration(color: AppColors.surfaceSand, shape: BoxShape.circle), child: SizedBox(width: 32, height: 32, child: Icon(LucideIcons.x, size: 16, color: AppColors.ink)))),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
