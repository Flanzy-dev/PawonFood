import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/listings_repository.dart';
import '../../core/motion/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/food_card.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/option_row.dart';

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
                  ? Center(
                      child: SingleChildScrollView(
                        child: EmptyState(
                          icon: LucideIcons.utensils,
                          title: 'Belum ada makanan di radius $km km',
                          body: 'Coba ubah filter di atas, atau perluas radius.',
                          actions: [
                            if (filters.isNotEmpty) AppButton(label: 'Hapus filter', onPressed: () => ref.read(feedFiltersProvider.notifier).state = {}),
                            if (ref.watch(radiusMetersProvider) < 2000) AppButton(label: 'Perluas radius ke 2 km', variant: AppButtonVariant.outline, onPressed: () => expandRadius(ref)),
                          ],
                        ),
                      ),
                    )
                  : EntranceScope(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => FadeSlideIn(
                          key: ValueKey(items[i].listing.id),
                          index: i,
                          child: FoodCard(listing: items[i].listing, distance: items[i].distance, onTap: () => context.push('/listing/${items[i].listing.id}')),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Urutkan" (B5e): radio rows like the other pickers, with a hint under the ranking option.
  void _pickSort(BuildContext context, WidgetRef ref) {
    final current = ref.read(feedSortProvider);
    showAppSheet<void>(
      context: context,
      builder: (ctx) => SheetBody(
        title: 'Urutkan',
        children: [
          for (final s in FeedSort.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OptionRow(
                title: s.label,
                subtitle: s.hint,
                selected: s == current,
                onTap: () {
                  ref.read(feedSortProvider.notifier).state = s;
                  closeSheet(ctx);
                },
              ),
            ),
        ],
      ),
    );
  }
}
