import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/pickup_points_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/option_row.dart';

/// C15b / C15b2 "Ubah titik ambil": pick a point on the map (starting from GPS) or one of the saved points. Applies to
/// this listing only. [current] is the listing's point; a point picked on the map shows first with "Dari peta".
/// Returns the chosen point, or null when dismissed.
Future<PickupPoint?> showPickupPointSheet(BuildContext context, {required PickupPoint current}) => showAppSheet<PickupPoint>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _PickupPointSheet(current: current),
    );

class _PickupPointSheet extends ConsumerWidget {
  const _PickupPointSheet({required this.current});

  final PickupPoint current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(pickupPointsProvider);
    final options = [if (current.fromMap) current, ...saved];
    return SheetBody(
      title: 'Ubah titik ambil',
      scroll: true,
      children: [
        OptionRow(
          title: 'Pilih lokasi di peta',
          subtitle: 'Mulai dari GPS · ${gpsPoint.address}',
          lead: OptionLead.badge,
          icon: LucideIcons.locateFixed,
          chevron: true,
          selected: false,
          onTap: () async {
            final picked = await context.push<PickupPoint>('/share/pick-point');
            if (picked != null && context.mounted) Navigator.of(context).pop(picked);
          },
        ),
        const SizedBox(height: 16),
        Text('Titik tersimpan', style: AppTypography.text(14, weight: 600, color: AppColors.inkMuted)),
        const SizedBox(height: 8),
        for (final p in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OptionRow(
              title: p.name,
              subtitle: p.address,
              lead: OptionLead.badge,
              icon: LucideIcons.mapPin,
              tag: p.fromMap ? 'Dari peta' : (p.primary ? 'Utama' : null),
              showCheck: true,
              selected: p.id == current.id,
              onTap: () => Navigator.of(context).pop(p),
            ),
          ),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/profile/points');
            },
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.primary),
            child: Text('Kelola titik tersimpan', style: AppTypography.text(15, weight: 700, color: AppColors.primary)),
          ),
        ),
      ],
    );
  }
}
