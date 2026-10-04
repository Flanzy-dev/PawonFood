import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/listings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/food_card.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';

/// B5b "Semua makanan": the full list behind "Semua" on Beranda, with the same filters and a sort option.
class AllFoodScreen extends ConsumerWidget {
  const AllFoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(sortedFeedProvider);
    final filters = ref.watch(feedFiltersProvider);
    final sort = ref.watch(feedSortProvider);
    final km = (ref.watch(radiusMetersProvider) / 1000).round();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', onTap: () => context.canPop() ? context.pop() : context.go('/')),
                  Expanded(child: Text('Segera habis di sekitarmu', textAlign: TextAlign.center, style: AppTypography.text(17, weight: 700))),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('${items.length} makanan dalam $km km', style: AppTypography.text(14, weight: 500, color: AppColors.inkMuted))),
                  TextButton(
                    onPressed: () => _pickSort(context, ref),
                    style: TextButton.styleFrom(foregroundColor: AppColors.ink, minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(sort.label, style: AppTypography.text(14, weight: 700)),
                      const SizedBox(width: 2),
                      const Icon(LucideIcons.chevronDown, size: 20, color: AppColors.ink),
                    ]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(child: EmptyState(icon: LucideIcons.utensils, title: 'Belum ada makanan di radius $km km', body: 'Coba ubah filter di atas, atau perluas radius dari Beranda.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => FoodCard(listing: items[i].listing, distance: items[i].distance, onTap: () => context.push('/listing/${items[i].listing.id}')),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickSort(BuildContext context, WidgetRef ref) {
    final current = ref.read(feedSortProvider);
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
              Text('Urutkan', style: AppTypography.titleL),
              const SizedBox(height: 8),
              for (final s in FeedSort.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  title: Text(s.label, style: AppTypography.text(16, weight: s == current ? 700 : 500)),
                  trailing: s == current ? const Icon(LucideIcons.check, color: AppColors.primary) : null,
                  onTap: () {
                    ref.read(feedSortProvider.notifier).state = s;
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
