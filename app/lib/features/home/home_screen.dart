import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/listings_repository.dart';
import '../../core/data/session_repository.dart';
import '../../core/services/geo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/food_card.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pawon_map.dart';
import '../../core/widgets/pills.dart';

/// B5 Beranda (and the empty state B6): location, headline, search, filters, 1 km mini-map and the feed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(sessionProvider.select((u) => u?.points ?? 0));
    final loc = ref.watch(locationProvider);
    final feed = ref.watch(feedProvider);
    final filters = ref.watch(feedFiltersProvider);
    final radius = ref.watch(radiusMetersProvider);
    final km = (radius / 1000).round();
    final area = loc.name.split(',').first;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, navContentInset(context)),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Lokasi kamu: ${loc.name}. Ketuk untuk mengubah.',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _pickLocation(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lokasi kamu', style: AppTypography.caption),
                          Row(
                            children: [
                              const Icon(LucideIcons.mapPin, size: 22, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Flexible(child: Text(loc.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(20, height: 26))),
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.chevronDown, size: 20, color: AppColors.ink),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PointsPill(points),
            ],
          ),
          const SizedBox(height: 16),
          Text('Lapar? Masih ada yang hangat di dekatmu.', style: AppTypography.titleXl),
          const SizedBox(height: 16),
          SearchField(hint: 'Cari lauk, nasi, roti...', onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in FeedFilter.values) ...[
                  AppChip(
                    label: f.label,
                    selected: filters.contains(f),
                    onTap: () {
                      final next = {...filters};
                      next.contains(f) ? next.remove(f) : next.add(f);
                      ref.read(feedFiltersProvider.notifier).state = next;
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: feed.isEmpty ? 92 : 164,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PawonMap(
                      mini: true,
                      center: loc.position,
                      radiusMeters: radius,
                      listings: [for (final i in feed.take(3)) i.listing],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Pill(
                      'Radius $km km${filters.contains(FeedFilter.walkable) ? ' · bisa jalan kaki' : ''}',
                      fill: AppColors.surface,
                      color: AppColors.primaryDark,
                      height: 30,
                      size: 13,
                      weight: 700,
                      hPad: 14,
                    ),
                  ),
                  if (feed.isNotEmpty)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Semantics(
                        button: true,
                        label: 'Lihat peta penuh',
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          elevation: 2,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(onTap: () => context.go('/map'), child: const SizedBox(width: 48, height: 48, child: Center(child: FullscreenIcon(size: 22)))),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (feed.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: EmptyState(
                image: 'assets/images/brand/berbagi.png',
                title: 'Belum ada makanan di radius $km km',
                body: 'Coba perluas radius, atau jadilah yang pertama berbagi di $area.',
                actions: [
                  if (radius < 2000) AppButton(label: 'Perluas radius ke 2 km', onPressed: () => expandRadius(ref)),
                  AppButton(label: 'Bagikan makananmu', variant: AppButtonVariant.outline, onPressed: () => context.push('/share/camera')),
                ],
              ),
            )
          else ...[
            SectionTitle('Segera habis di sekitarmu', actionLabel: 'Semua', onAction: () => context.push('/semua')),
            const SizedBox(height: 8),
            for (final item in feed) ...[
              FoodCard(listing: item.listing, distance: item.distance, onTap: () => context.push('/listing/${item.listing.id}')),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  void _pickLocation(BuildContext context, WidgetRef ref) {
    final current = ref.read(locationProvider);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ganti lokasi', style: AppTypography.titleL),
              const SizedBox(height: 8),
              for (final l in locations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: Icon(LucideIcons.mapPin, color: l.name == current.name ? AppColors.primary : AppColors.inkMuted),
                  title: Text(l.name, style: AppTypography.text(16, weight: l.name == current.name ? 700 : 500)),
                  trailing: l.name == current.name ? const Icon(LucideIcons.check, color: AppColors.primary) : null,
                  onTap: () {
                    ref.read(locationProvider.notifier).select(l);
                    ref.read(radiusMetersProvider.notifier).state = walkableRadiusMeters;
                    ref.read(feedFiltersProvider.notifier).state = {FeedFilter.walkable};
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
