import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/data/settings_repository.dart';
import '../../core/models/enums.dart';
import '../../core/models/listing.dart';
import '../../core/motion/motion.dart';
import '../../core/services/geo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/map_cluster.dart';
import '../../core/widgets/mini_food_card.dart';
import '../../core/widgets/packed_filter_chip.dart';
import 'map_pin_card.dart';
import 'radius_indicator.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/radius_sheet.dart';
import '../../core/widgets/pawon_map.dart';

/// Listing id selected on the map (pin tap); the selected listing is listed first in the sheet.
final mapSelectedProvider = StateProvider<String?>((ref) => null);

/// Listings shown on the full map: everything within the chosen radius of the chosen location (500 m, 1 km or 2 km,
/// picked with the round radius indicator), filtered by the category chips (shared with Beranda, so both tabs show the
/// same category) and the "Sudah dibungkus" chip (also shared).
final mapListingsProvider = Provider<List<FeedItem>>((ref) {
  final now = ref.watch(clockProvider)();
  final here = ref.watch(locationProvider).position;
  final radius = ref.watch(radiusMetersProvider);
  final category = ref.watch(categoryFilterProvider);
  final packedOnly = ref.watch(feedFiltersProvider).contains(FeedFilter.packed);
  final items = <FeedItem>[];
  for (final l in ref.watch(listingsProvider)) {
    if (!isVisibleListing(l, now)) continue;
    final d = distanceMeters(here, l.position);
    if (d > radius) continue;
    if (category != null && l.category != category) continue;
    if (packedOnly && l.packaging != Packaging.dibungkus) continue;
    items.add(FeedItem(l, d));
  }
  items.sort((a, b) => a.distance.compareTo(b.distance));
  return items;
});

/// Heights of the bottom sheet levels (logical px): collapsed = handle + one card, half, and full = up to the chips.
const double _collapsedPx = 148;
const double _halfPx = 360;

/// B7 Peta: price-label pins, the radius ring, clusters, and a draggable bottom sheet (collapsed / half / full) that
/// lists the food cards. Tapping a pin swaps the sheet for a floating product card (B12c); the round radius indicator
/// (bottom right) opens the radius picker (B12d). The header keeps the GPS button.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  final _controller = MapController();
  final _sheet = DraggableScrollableController();
  final _extentPx = ValueNotifier<double>(_collapsedPx);

  /// Listing whose floating card is open (pin tapped); null shows the bottom sheet.
  String? _cardId;
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
      if (l != null && mounted) _glide(l.position, 16);
    });
  }

  AnimationController? _camera;

  /// Moves the map camera smoothly (flutter_map's move() jumps).
  void _glide(LatLng to, double zoom) {
    final cam = _controller.camera;
    if (Motion.reduced(context)) {
      _controller.move(to, zoom);
      return;
    }
    _camera?.dispose();
    final c = AnimationController(vsync: this, duration: Motion.slow * 2);
    _camera = c;
    final lat = Tween(begin: cam.center.latitude, end: to.latitude), lng = Tween(begin: cam.center.longitude, end: to.longitude);
    final z = Tween(begin: cam.zoom, end: zoom);
    final t = CurvedAnimation(parent: c, curve: Motion.move);
    c.addListener(() => _controller.move(LatLng(lat.transform(t.value), lng.transform(t.value)), z.transform(t.value)));
    c.forward();
  }

  @override
  void dispose() {
    _camera?.dispose();
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

  /// Pixels the camera is shifted so the opened pin sits in the free area between the header and the floating card.
  static const _pinShiftPx = 88.0;

  /// Zoom used for a tapped pin: about 360 m across, so the street at the pickup spot is readable.
  static const _pinZoom = 17.0;

  void _select(Listing l) {
    ref.read(mapSelectedProvider.notifier).state = l.id;
    setState(() => _cardId = l.id);
    final dLat = _pinShiftPx * metersPerPixel(l.position.latitude, _pinZoom) / 110574;
    _glide(LatLng(l.position.latitude - dLat, l.position.longitude), _pinZoom);
  }

  /// ✕ on the card: back to the overview of the radius.
  void _closeCard() {
    if (_cardId == null) return;
    setState(() => _cardId = null);
    final center = ref.read(locationProvider).position;
    _glide(center, zoomForSpan(center.latitude, ref.read(radiusMetersProvider) * 2, 250));
  }

  /// Tap on the bare map: the card goes away, the camera stays where the user put it.
  void _dismissCard() {
    if (_cardId != null) setState(() => _cardId = null);
  }

  void _pickRadius() => showRadiusSheet(
        context,
        title: 'Jangkauan pencarian',
        subtitle: 'Tampilkan makanan dalam radius ini',
        current: (ref) => ref.watch(radiusMetersProvider),
        onPick: (ref, m) => ref.read(radiusMetersProvider.notifier).state = m,
      );

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locationProvider);
    final items = ref.watch(mapListingsProvider);
    final category = ref.watch(categoryFilterProvider);
    final packedOnly = ref.watch(feedFiltersProvider).contains(FeedFilter.packed);
    final selectedId = ref.watch(mapSelectedProvider);
    FeedItem? selected;
    for (final i in items) {
      if (i.listing.id == selectedId) selected = i;
    }
    selected ??= items.where((i) => !i.listing.isOwn).firstOrNull ?? items.firstOrNull;
    final ordered = [?selected, for (final i in items) if (i != selected) i];
    final area = loc.name;
    final navInset = navBarHeight + MediaQuery.paddingOf(context).bottom;
    final radius = ref.watch(radiusMetersProvider);
    final radiusText = formatRadius(radius);
    // The floating card replaces the sheet while a pin is open.
    final cardItem = items.where((i) => i.listing.id == _cardId).firstOrNull;

    return Stack(
      children: [
        AnimatedPositioned(
          duration: Motion.of(context, Motion.base),
          curve: Motion.move,
          left: 0,
          right: 0,
          top: 0,
          bottom: _mapInset,
          child: PawonMap(
            controller: _controller,
            center: loc.position,
            listings: [for (final i in items) i.listing],
            selectedId: cardItem?.listing.id, // green only while its card is open
            onSelect: _select,
            radiusMeters: radius,
            onTapMap: _dismissCard,
            attributionBottom: navInset + (cardItem != null ? navFabRise + 12 + MapPinCard.height : _creditLift) + 6,
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
              return IgnorePointer(
                ignoring: cardItem != null,
                child: AnimatedSlide(
                duration: Motion.of(context, Motion.base),
                curve: Motion.move,
                offset: cardItem != null ? const Offset(0, 1) : Offset.zero,
                child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _minFraction,
                minChildSize: _minFraction,
                maxChildSize: maxFraction,
                snap: true,
                snapSizes: [halfFraction],
                builder: (context, scroll) {
                  return DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, -4))],
                    ),
                    // Clip to the panel's rounded top, so scrolled cards never poke out over the map at the corners.
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 10),
                        ValueListenableBuilder<double>(
                          valueListenable: _extentPx,
                          builder: (context, px, _) => AnimatedSize(
                            // 1 ms instead of zero when motion is reduced: a zero-length AnimatedSize re-dirties itself
                            // inside this sliver's layout.
                            duration: Motion.reduced(context) ? const Duration(milliseconds: 1) : Motion.fast,
                            curve: Motion.move,
                            alignment: Alignment.topLeft,
                            child: px > _collapsedPx + 24 && ordered.isNotEmpty
                                ? Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('${ordered.length} makanan dalam $radiusText', style: AppTypography.display(17, weight: 700, height: 22)))
                                : const SizedBox(width: double.infinity),
                          ),
                        ),
                        if (ordered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 16),
                            child: Column(children: [
                              Text('Belum ada makanan di radius $radiusText', textAlign: TextAlign.center, style: AppTypography.display(20, weight: 800, height: 26)),
                              const SizedBox(height: 6),
                              Text('Coba perluas radius, atau jadilah yang pertama berbagi di ${area.split(',').first}.', textAlign: TextAlign.center, style: AppTypography.bodyMuted),
                              if (category != null || packedOnly) ...[
                                const SizedBox(height: 12),
                                AppButton(
                                  label: 'Hapus filter',
                                  variant: AppButtonVariant.outline,
                                  onPressed: () {
                                    ref.read(categoryFilterProvider.notifier).state = null;
                                    ref.read(feedFiltersProvider.notifier).state = {...ref.read(feedFiltersProvider)}..remove(FeedFilter.packed);
                                  },
                                ),
                              ],
                            ]),
                          )
                        else
                          for (final (i, item) in ordered.indexed) ...[
                            if (i > 0) const SizedBox(height: 12),
                            MiniFoodCard(listing: item.listing, distance: item.distance, onTap: () => context.push('/listing/${item.listing.id}')),
                          ],
                      ],
                    ),
                    ),
                  );
                },
              ),
              ),
              );
            },
          ),
        ),
        // Round radius indicator: above the sheet (following it), or above the floating card.
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.base),
            child: cardItem != null
                ? Align(
                    key: ValueKey('card_${cardItem.listing.id}'),
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, navInset + navFabRise + 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RadiusIndicator(meters: radius, onTap: _pickRadius),
                          const SizedBox(height: 12),
                          MapPinCard(listing: cardItem.listing, distance: cardItem.distance, onTap: () => context.push('/listing/${cardItem.listing.id}'), onClose: _closeCard),
                        ],
                      ),
                    ),
                  )
                : ValueListenableBuilder<double>(
                    key: const ValueKey('sheet'),
                    valueListenable: _extentPx,
                    builder: (context, px, _) {
                      final hidden = px > _halfPx + 24; // full list: the sheet covers the corner
                      return Stack(children: [
                        Positioned(
                          right: 16,
                          bottom: navInset + px.clamp(_collapsedPx, _halfPx) + 12,
                          child: IgnorePointer(
                            ignoring: hidden,
                            child: AnimatedOpacity(opacity: hidden ? 0 : 1, duration: Motion.of(context, Motion.fast), child: RadiusIndicator(meters: radius, onTap: _pickRadius)),
                          ),
                        ),
                      ]);
                    },
                  ),
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
                            Text('Radius $radiusText dari', style: AppTypography.text(13, color: AppColors.inkMuted)),
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
                          child: InkWell(onTap: () => _glide(loc.position, 14.2), child: const SizedBox(width: 48, height: 48, child: Icon(LucideIcons.locateFixed, size: 24, color: AppColors.primary))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    // Same category chips as Beranda (intentionally English), one shared selection.
                    for (final c in <FoodCategory?>[null, ...FoodCategory.values]) ...[
                      AppChip(label: c?.chip ?? 'All', selected: category == c, onTap: () => ref.read(categoryFilterProvider.notifier).state = c),
                      const SizedBox(width: 8),
                    ],
                    const PackedFilterChip(),
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
