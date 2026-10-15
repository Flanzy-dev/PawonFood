import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/listing.dart';
import '../motion/motion.dart';
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

/// Map used on Beranda (mini, non-interactive, price pins) and Peta (full, tappable price pins and clusters).
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
    this.keepClear,
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

  /// Mini map only: areas covered by overlays (radius label, map button) that price pins must not sit under.
  final List<Rect> Function(Size size)? keepClear;

  /// The mini map shows at most this many price pins.
  static const miniPins = 2;

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

  /// Label shown on a listing's price pin.
  static String _label(Listing l) => l.isFree ? 'Gratis' : formatRupiah(l.price);

  /// Mini map callouts: for the nearest listings, a small dot on the exact spot and the price pill beside it (right,
  /// left, above or below, whichever side is free). At this zoom everything within 1 km sits close to the user dot,
  /// so a pill centred on its point would cover the dot or another pill. Pills stay fully on the map and clear of each
  /// other, the dots, the user dot and the [PawonMap.keepClear] overlays. Returns each listing with the pill's
  /// top-left relative to the listing's point.
  List<(Listing, Offset)> _miniCallouts(Size size, LatLng user) {
    final c = widget.center, mpp = metersPerPixel(c.latitude, _zoom);
    final cosLat = math.cos(c.latitude * math.pi / 180);
    Offset toPx(LatLng p) => Offset(size.width / 2 + (p.longitude - c.longitude) * 111320 * cosLat / mpp, size.height / 2 - (p.latitude - c.latitude) * 110574 / mpp);
    final style = AppTypography.text(15, weight: 700);
    final taken = <Rect>[Rect.fromCircle(center: toPx(user), radius: 16), ...?widget.keepClear?.call(size)];
    final bounds = (Offset.zero & size).deflate(4);
    final out = <(Listing, Offset)>[];
    for (final l in widget.listings) {
      if (out.length == PawonMap.miniPins) break;
      final tp = TextPainter(text: TextSpan(text: _label(l), style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
      final w = tp.width + 31, p = toPx(l.position), dot = Rect.fromCircle(center: p, radius: 6);
      tp.dispose();
      if (!bounds.contains(p) || taken.any((t) => t.overlaps(dot))) continue;
      const gap = _calloutGap;
      for (final off in [const Offset(gap, -_pinH / 2), Offset(-gap - w, -_pinH / 2), Offset(-w / 2, -gap - _pinH), Offset(-w / 2, gap)]) {
        final r = (p + off) & Size(w, _pinH);
        if (!bounds.contains(r.topLeft) || !bounds.contains(r.bottomRight) || taken.any((t) => t.inflate(4).overlaps(r))) continue;
        taken..add(r)..add(dot);
        out.add((l, off));
        break;
      }
    }
    return out;
  }

  static const _pinH = 36.0, _calloutGap = 10.0;

  /// A mini-map callout: the dot sits on the listing's point (the marker's centre), the pill at [off] from it.
  Marker _callout(Listing l, Offset off) {
    const w = 280.0, h = 2 * (_pinH + _calloutGap) + 8;
    final label = _label(l);
    return Marker(
      point: l.position,
      width: w,
      height: h,
      child: IgnorePointer(
        child: Semantics(
          label: '${l.name}, $label',
          excludeSemantics: true,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: w / 2 - 5,
              top: h / 2 - 5,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: l.isFree ? AppColors.primary : AppColors.accent,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ),
            Positioned(left: w / 2 + off.dx, top: h / 2 + off.dy, child: _PricePin(label: label, free: l.isFree)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.mini) return _map(null);
    return LayoutBuilder(builder: (_, box) => _map(box.biggest));
  }

  Widget _map(Size? miniSize) {
    final tiles = ref.watch(tilesEnabledProvider);
    final user = widget.userPosition ?? widget.center;
    // The selected listing always stays a single, highlighted pin drawn on top; the rest may cluster.
    final rest = [for (final l in widget.listings) if (l.id != widget.selectedId) l];
    final picked = [for (final l in widget.listings) if (l.id == widget.selectedId) l];
    final clusters = miniSize != null
        ? const <MapCluster>[]
        : [...clusterListings(rest, 72 * metersPerPixel(widget.center.latitude, _zoom)), for (final l in picked) MapCluster(l)];
    final callouts = miniSize != null ? _miniCallouts(miniSize, user) : const <(Listing, Offset)>[];
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
        if (tiles) pawonTileLayer(),
        PolygonLayer(polygons: [
          Polygon(
            points: circlePoints(widget.center, widget.radiusMeters),
            color: AppColors.primary.withValues(alpha: 0.1),
            borderColor: AppColors.primaryDark,
            borderStrokeWidth: 2.5,
            pattern: StrokePattern.dashed(segments: const [8, 6]),
          ),
        ]),
        MarkerLayer(markers: [
          for (final c in clusters)
            if (c.isSingle) _pin(c.listings.first) else _cluster(c),
          for (final (l, off) in callouts) _callout(l, off),
          Marker(point: user, width: 28, height: 28, child: const UserDot()),
        ]),
        OsmCredit(bottom: widget.attributionBottom),
      ],
    );
  }

  Marker _pin(Listing l) {
    final label = _label(l);
    final selected = l.id == widget.selectedId;
    return Marker(
      point: l.position,
      width: 124,
      height: 44, // tap target
      child: Semantics(
        button: true,
        selected: selected,
        label: '${l.name}, $label',
        child: GestureDetector(
          onTap: () => widget.onSelect?.call(l),
          // The selected pin grows a little and turns green, so the eye follows the tap.
          child: Center(
            child: AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: Motion.of(context, Motion.base),
              curve: Motion.pop,
              child: _PricePin(label: label, free: l.isFree, selected: selected),
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

}

/// OSM tiles tinted into the cream/sand palette (shared by every map in the app).
TileLayer pawonTileLayer() => TileLayer(
      urlTemplate: _tileUrl,
      userAgentPackageName: _userAgentPackage,
      tileBuilder: (context, tile, _) => ColorFiltered(colorFilter: _tileTint(), child: tile),
      errorTileCallback: (_, _, _) {}, // offline: keep the sand background instead of logging every tile
    );

/// Circle of [meters] around [center] as a polygon (flutter_map circles cannot be dashed).
List<LatLng> circlePoints(LatLng center, double meters) {
  const distance = Distance();
  return [for (var deg = 0; deg < 360; deg += 4) distance.offset(center, meters, deg.toDouble())];
}

/// Teardrop map pin as SVG ([hex] fill, white hole).
/// Price-label pin: white pill with an accent border (green for free food), filled green when selected.
class _PricePin extends StatelessWidget {
  const _PricePin({required this.label, required this.free, this.selected = false});

  final String label;
  final bool free;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: selected ? null : Border.all(color: free ? AppColors.primary : AppColors.accent, width: 1.5),
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(label, softWrap: false, maxLines: 1, style: AppTypography.text(15, weight: 700, color: selected ? AppColors.background : AppColors.ink)),
      );
}

String teardropSvg(String hex, {double scale = 1}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" width="${28 * scale}" height="${36 * scale}" viewBox="0 0 28 36"><path d="M14 0C6.3 0 0 6.2 0 13.8 0 24 14 36 14 36s14-12 14-22.2C28 6.2 21.7 0 14 0Z" fill="$hex"/><circle cx="14" cy="13.5" r="5" fill="#fff"/></svg>';

/// "© OpenStreetMap contributors", required on every map.
class OsmCredit extends StatelessWidget {
  const OsmCredit({super.key, this.bottom = 4});

  final double bottom;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 6, bottom: bottom),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(color: AppColors.background.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(4)),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), child: Text('© OpenStreetMap contributors', style: AppTypography.text(10, color: AppColors.inkMuted))),
            ),
          ),
        ),
      );
}

/// White label pill next to a map marker ("Kamu", "Warteg Bu Siti", "Titik ambil").
class MapLabel extends StatelessWidget {
  const MapLabel(this.text, {super.key, this.outlined = false});

  final String text;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(color: AppColors.primaryDark, width: 1.2) : null,
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Center(widthFactor: 1, child: Text(text, maxLines: 1, softWrap: false, style: AppTypography.text(13, weight: 700, color: AppColors.primaryDark))),
      );
}

/// The user's location: green dot in a white ring.
class UserDot extends StatelessWidget {
  const UserDot({super.key});

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
