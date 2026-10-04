import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/models/listing.dart';
import '../../core/services/geo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/mini_food_card.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pawon_map.dart';

enum MapFilter {
  all('Semua'),
  free('Gratis'),
  warm('Sedang hangat');

  const MapFilter(this.label);
  final String label;
}

final mapFilterProvider = StateProvider<MapFilter>((ref) => MapFilter.all);

/// Listing id selected on the map (pin tap); the selected listing is listed first in the sheet.
final mapSelectedProvider = StateProvider<String?>((ref) => null);

/// Listings shown on the full map: everything within 2 km of the chosen location, filtered by the map chips.
final mapListingsProvider = Provider<List<FeedItem>>((ref) {
  final now = ref.watch(clockProvider)();
  final here = ref.watch(locationProvider).position;
  final filter = ref.watch(mapFilterProvider);
  final items = <FeedItem>[];
  for (final l in ref.watch(listingsProvider)) {
    if (!isVisibleListing(l, now)) continue;
    final d = distanceMeters(here, l.position);
    if (d > 2000) continue;
    if (filter == MapFilter.free && !l.isFree) continue;
    if (filter == MapFilter.warm && !l.isWarm(now)) continue;
    items.add(FeedItem(l, d));
  }
  items.sort((a, b) => a.distance.compareTo(b.distance));
  return items;
});

/// Heights of the bottom sheet levels (logical px): collapsed = handle + one card, half, and full = up to the chips.
const double _collapsedPx = 148;
const double _halfPx = 360;

/// B7 Peta: price-label pins, the 1 km radius, clusters, and a draggable bottom sheet (collapsed / half / full)
/// that lists the food cards. The header keeps the GPS button.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _controller = MapController();
  final _sheet = DraggableScrollableController();
  final _extentPx = ValueNotifier<double>(_collapsedPx);
  ScrollController? _list;
  Timer? _settle;
  double _minFraction = 0.2;

  /// Map bottom inset and credit position, updated once the sheet stops moving so the map is not resized every frame.
  double _mapInset = 0;
  double _creditLift = _collapsedPx;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSheetMoved);
    // Coming from a selected listing: focus the map on it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = ref.read(mapSelectedProvider);
      final l = id == null ? null : ref.read(listingByIdProvider(id));
      if (l != null && mounted) _controller.move(l.position, 16);
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    _sheet.dispose();
    _extentPx.dispose();
    super.dispose();
  }

  void _onSheetMoved() {
    if (!_sheet.isAttached) return;
    final px = _sheet.pixels;
    _extentPx.value = px;
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      final clamped = px.clamp(_collapsedPx, _halfPx);
      setState(() {
        _mapInset = 0.4 * (clamped - _collapsedPx); // half level lifts the radius and pins by about 40 px
        _creditLift = clamped;
      });
    });
  }

  void _select(Listing l) {
    ref.read(mapSelectedProvider.notifier).state = l.id;
    if (_list?.hasClients ?? false) _list!.jumpTo(0);
    if (_sheet.isAttached) _sheet.animateTo(_minFraction, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locationProvider);
    final items = ref.watch(mapListingsProvider);
    final filter = ref.watch(mapFilterProvider);
    final selectedId = ref.watch(mapSelectedProvider);
    FeedItem? selected;
    for (final i in items) {
      if (i.listing.id == selectedId) selected = i;
    }
    selected ??= items.where((i) => !i.listing.isOwn).firstOrNull ?? items.firstOrNull;
    final ordered = [?selected, for (final i in items) if (i != selected) i];
    final area = loc.name;
    final navInset = navBarHeight + MediaQuery.paddingOf(context).bottom;
    final far = items.any((i) => i.distance > 1000);

    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          top: 0,
          bottom: _mapInset,
          child: PawonMap(
            controller: _controller,
            center: loc.position,
            listings: [for (final i in items) i.listing],
            selectedId: selected?.listing.id,
            onSelect: _select,
            attributionBottom: navInset + _creditLift + 6,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: navInset,
          child: LayoutBuilder(
            builder: (context, c) {
              final h = c.maxHeight;
              final top = MediaQuery.paddingOf(context).top + 132; // header + chips, plus a gap
              _minFraction = (_collapsedPx / h).clamp(0.05, 0.5);
              final maxFraction = ((h - top) / h).clamp(_minFraction + 0.1, 0.95);
              final halfFraction = (_halfPx / h).clamp(_minFraction + 0.05, maxFraction - 0.05);
              return DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _minFraction,
                minChildSize: _minFraction,
                maxChildSize: maxFraction,
                snap: true,
                snapSizes: [halfFraction],
                builder: (context, scroll) {
                  _list = scroll;
                  return DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, -4))],
                    ),
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 10),
                        ValueListenableBuilder<double>(
                          valueListenable: _extentPx,
                          builder: (context, px, _) => AnimatedSize(
                            duration: const Duration(milliseconds: 160),
                            alignment: Alignment.topLeft,
                            child: px > _collapsedPx + 24 && ordered.isNotEmpty
                                ? Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('${ordered.length} makanan dalam ${far ? 2 : 1} km', style: AppTypography.display(17, weight: 700, height: 22)))
                                : const SizedBox(width: double.infinity),
                          ),
                        ),
                        if (ordered.isEmpty)
                          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('Belum ada makanan di area ini.', textAlign: TextAlign.center, style: AppTypography.bodyMuted))
                        else
                          for (final (i, item) in ordered.indexed) ...[
                            if (i > 0) const SizedBox(height: 12),
                            MiniFoodCard(listing: item.listing, distance: item.distance, onTap: () => context.push('/listing/${item.listing.id}')),
                          ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))]),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Radius 1 km dari', style: AppTypography.text(13, color: AppColors.inkMuted)),
                            Text(area, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(20, height: 26)),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Pusatkan ke lokasi saya',
                        child: Material(
                          color: AppColors.surfaceSand,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(onTap: () => _controller.move(loc.position, 14.2), child: const SizedBox(width: 44, height: 44, child: Icon(LucideIcons.locateFixed, size: 24, color: AppColors.primary))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final f in MapFilter.values) ...[
                      AppChip(label: f.label, selected: f == filter, onTap: () => ref.read(mapFilterProvider.notifier).state = f),
                      const SizedBox(width: 8),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
