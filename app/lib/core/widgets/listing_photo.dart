import 'dart:io';

import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../theme/app_colors.dart';

/// Food photo: an asset (mock data) or a file captured by the live camera. Camera-only capture, no gallery.
class ListingPhoto extends StatelessWidget {
  const ListingPhoto(this.listing, {super.key, this.width, this.height, this.radius = 12});

  final Listing listing;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(color: AppColors.foodWarm, child: Center(child: Icon(Icons.restaurant, color: AppColors.background.withValues(alpha: 0.7))));
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width == null ? null : (width! * dpr).round();
    final Widget image = listing.localPhotoPath != null
        ? Image.file(File(listing.localPhotoPath!), fit: BoxFit.cover, cacheWidth: cacheW, errorBuilder: (_, _, _) => fallback)
        : Image.asset(listing.photo, fit: BoxFit.cover, cacheWidth: cacheW, errorBuilder: (_, _, _) => fallback);
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: SizedBox(width: width, height: height, child: image));
  }
}
