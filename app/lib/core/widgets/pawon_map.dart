import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../models/listing.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'map_cluster.dart';

/// Turned off in widget tests so no tile is requested from the network.
final tilesEnabledProvider = Provider<bool>((ref) => true);

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgentPackage = 'id.pawonfood.pawonfood';

/// Warm, desaturated tint so OSM tiles sit in the cream/sand palette of the design.
ColorFilter _tileTint() {
  // Partial desaturation (keep 35% of the color) followed by a per-channel scale towards cream.
  // Then blend 35% of the map sand color in, so roads and labels stay readable but quiet.
  const sat = 0.3, keep = 0.65;
  const lum = [0.2126, 0.7152, 0.0722]; // R, G, B luminance weights
  const sand = [232.0, 221.0, 201.0]; // AppColors.mapSand
  final m = <double>[];
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
      m.add((lum[col] * (1 - sat) + (row == col ? sat : 0)) * keep);
    }
    m.addAll([0, sand[row] * (1 - keep)]);
  }
  return ColorFilter.matrix([...m, 0, 0, 0, 1, 0]);
}

/// Map used on Beranda (mini, non-interactive, teardrop pins) and Peta (full, price-label pins and clusters).
class PawonMap extends ConsumerStatefulWidget {
  const PawonMap({
    super.key,
    required this.center,
    required this.listings,
    this.mini = false,
    this.selectedId,
    this.onSelect,
    this.controller,
    this.radiusMeters = 1000,
    this.initialZoom,
    this.userPosition,
    this.onTapMap,
    this.attributionBottom = 4,
  });

  final LatLng center;
  final LatLng? userPosition;
  final List<Listing> listings;
  final bool mini;
  final String? selectedId;
  final ValueChanged<Listing>? onSelect;
  final MapController? controller;
  final double radiusMeters;
  final double? initialZoom;
  final VoidCallback? onTapMap;

  /// Distance of the OSM credit from the bottom edge (the full map lifts it above the navigation bar).
  final double attributionBottom;

  @override
  ConsumerState<PawonMap> createState() => _PawonMapState();
}

class _PawonMapState extends ConsumerState<PawonMap> {
  late final MapController _controller = widget.controller ?? MapController();
  late double _zoom = widget.initialZoom ?? zoomForSpan(widget.center.latitude, widget.radiusMeters * 2, widget.mini ? 128 : 250);

  @override
  void didUpdateWidget(covariant PawonMap old) {
    super.didUpdateWidget(old);
    if (old.center != widget.center || old.radiusMeters != widget.radiusMeters) {
      final z = widget.initialZoom ?? zoomForSpan(widget.center.latitude, widget.radiusMeters * 2, widget.mini ? 128 : 250);
      _zoom = z;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.move(widget.center, z);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = ref.watch(tilesEnabledProvider);
    final user = widget.userPosition ?? widget.center;
    // The selected listing always stays a single, highlighted pin drawn on top; the rest may cluster.
    final rest = [for (final l in widget.listings) if (l.id != widget.selectedId) l];
    final picked = [for (final l in widget.listings) if (l.id == widget.selectedId) l];
    final clusters = widget.mini
        ? [for (final l in widget.listings) MapCluster(l)]
        : [...clusterListings(rest, 72 * metersPerPixel(widget.center.latitude, _zoom)), for (final l in picked) MapCluster(l)];
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: _zoom,
        minZoom: 11,
        maxZoom: 18,
        backgroundColor: AppColors.mapSand,
        interactionOptions: InteractionOptions(flags: widget.mini ? InteractiveFlag.none : InteractiveFlag.all & ~InteractiveFlag.rotate),
        onTap: (_, _) => widget.onTapMap?.call(),
        onPositionChanged: (camera, _) {
          if ((camera.zoom - _zoom).abs() > 0.05 && !widget.mini) setState(() => _zoom = camera.zoom);
        },
      ),
      children: [
        if (tiles)
          TileLayer(
            urlTemplate: _tileUrl,
            userAgentPackageName: _userAgentPackage,
            tileBuilder: (context, tile, _) => ColorFiltered(colorFilter: _tileTint(), child: tile),
            errorTileCallback: (_, _, _) {}, // offline: keep the sand background instead of logging every tile
          ),
        PolygonLayer(polygons: [
          Polygon(
            points: _circle(widget.center, widget.radiusMeters),
            color: AppColors.primary.withValues(alpha: 0.1),
            borderColor: AppColors.primaryDark,
            borderStrokeWidth: 2.5,
            pattern: StrokePattern.dashed(segments: const [8, 6]),
          ),
        ]),
        MarkerLayer(markers: [
          for (final c in clusters)
            if (c.isSingle) _pin(c.listings.first) else _cluster(c),
          Marker(point: user, width: 28, height: 28, child: const _UserDot()),
        ]),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 6, bottom: widget.attributionBottom),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.background.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(4)),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), child: Text('© OpenStreetMap contributors', style: AppTypography.text(10, color: AppColors.inkMuted))),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Marker _pin(Listing l) {
    if (widget.mini) {
      return Marker(
        point: l.position,
        width: 28,
        height: 36,
        alignment: Alignment.topCenter,
        child: SvgPicture.string(_teardrop(l.isFree ? '#2F5D39' : '#B15732'), semanticsLabel: l.name),
      );
    }
    final label = l.isFree ? 'Gratis' : formatRupiah(l.price);
    final selected = l.id == widget.selectedId;
    return Marker(
      point: l.position,
      width: 124,
      height: 40,
      child: Semantics(
        button: true,
        label: '${l.name}, $label',
        child: GestureDetector(
          onTap: () => widget.onSelect?.call(l),
          child: Center(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: selected ? null : Border.all(color: l.isFree ? AppColors.primary : AppColors.accent, width: 1.5),
                boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Text(label, softWrap: false, maxLines: 1, style: AppTypography.text(15, weight: 700, color: selected ? AppColors.background : AppColors.ink)),
            ),
          ),
        ),
      ),
    );
  }

  Marker _cluster(MapCluster c) => Marker(
        point: c.center,
        width: 48,
        height: 48,
        child: Semantics(
          button: true,
          label: '${c.count} listing di area ini',
          child: GestureDetector(
            onTap: () => _controller.move(c.center, (_zoom + 1.5).clamp(11, 18)),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3),
                boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Text('${c.count}', style: AppTypography.display(18, weight: 700, color: AppColors.background)),
            ),
          ),
        ),
      );

  /// Circle of [meters] around [center] as a polygon (flutter_map circles cannot be dashed).
  static List<LatLng> _circle(LatLng center, double meters) {
    const distance = Distance();
    return [for (var deg = 0; deg < 360; deg += 4) distance.offset(center, meters, deg.toDouble())];
  }

  static String _teardrop(String hex) =>
      '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="36" viewBox="0 0 28 36"><path d="M14 0C6.3 0 0 6.2 0 13.8 0 24 14 36 14 36s14-12 14-22.2C28 6.2 21.7 0 14 0Z" fill="$hex"/><circle cx="14" cy="13.5" r="5" fill="#fff"/></svg>';
}

/// The user's location: green dot in a white ring.
class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Lokasi kamu',
        child: Container(
          decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
          padding: const EdgeInsets.all(6.5),
          child: const DecoratedBox(decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
        ),
      );
}
