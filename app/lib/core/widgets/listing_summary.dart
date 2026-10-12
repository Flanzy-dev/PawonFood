import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/listing.dart';
import '../motion/pressable.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'listing_photo.dart';

/// Photo, name and one meta line in a white card. Pinned on top of the chat and repeated on the payment, QR,
/// scanner and review screens so the user always sees which food the step is about.
class ListingSummaryCard extends StatelessWidget {
  const ListingSummaryCard({super.key, required this.listing, required this.subtitle, this.onTap, this.dark = false, this.footer, this.photo = 56});

  final Listing listing;
  final String subtitle;
  final VoidCallback? onTap;

  /// Translucent card for the dark scanner screen.
  final bool dark;

  /// Extra line under the subtitle ("✓ Pengambilan berhasil · 19.55").
  final Widget? footer;
  final double photo;

  @override
  Widget build(BuildContext context) => Pressable(
        enabled: onTap != null,
        scale: 0.98,
        child: Material(
          color: dark ? AppColors.cameraControl : AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: dark ? BorderSide.none : const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ListingPhoto(listing, width: photo, height: photo, radius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(listing.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(16, weight: 700, height: 21, color: dark ? AppColors.background : AppColors.ink)),
                        const SizedBox(height: 2),
                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.text(13, height: 18, color: dark ? AppColors.cameraText : AppColors.inkMuted)),
                        ?footer,
                      ],
                    ),
                  ),
                  if (onTap != null) Icon(LucideIcons.chevronRight, size: 22, color: dark ? AppColors.cameraText : AppColors.inkMuted),
                ],
              ),
            ),
          ),
        ),
      );
}
