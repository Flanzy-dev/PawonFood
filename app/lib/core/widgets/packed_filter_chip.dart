import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/listings_repository.dart';
import '../theme/app_colors.dart';
import 'app_chip.dart';

/// "Sudah dibungkus" at the end of the Beranda and Peta chip rows, after a thin divider (it is not a category). One
/// selection, shared with the full list ([FeedFilter.packed]).
class PackedFilterChip extends ConsumerWidget {
  const PackedFilterChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(feedFiltersProvider);
    final on = filters.contains(FeedFilter.packed);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 1, height: 24, color: AppColors.border),
      const SizedBox(width: 8),
      AppChip(
        label: FeedFilter.packed.label,
        selected: on,
        onTap: () => ref.read(feedFiltersProvider.notifier).state = on ? ({...filters}..remove(FeedFilter.packed)) : {...filters, FeedFilter.packed},
      ),
    ]);
  }
}
