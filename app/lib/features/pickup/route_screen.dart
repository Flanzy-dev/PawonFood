import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/motion_widgets.dart';
import '../../core/services/formatters.dart';
import '../../core/services/location_service.dart';
import '../../core/services/route_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/countdown.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pawon_map.dart';
import '../../core/widgets/pills.dart';

enum _Stage { plan, walking, arrived }

/// B8b Rute ke titik ambil → B8c Dalam perjalanan → B8d Sudah sampai. Walking only.
///
/// Two trips share the screen: the receiver walking to the pickup point, or, for "Minta diantar", the provider taking
/// the food to the delivery address ("Rute antar", then "Buka QR ambil" on arrival). Both use the foot router: within
/// 1 km it also follows the gangs a motorbike takes.
///
/// The start is the phone's GPS position when it can be read (else the chosen area, or the pickup point for a
/// delivery), and the route comes from the OpenStreetMap foot router, with a straight-line estimate while it loads or
/// when it cannot be found. While walking, "Kamu" follows live GPS and arrives within 30 m of the destination; without
/// GPS, or on a long press of "Mulai jalan" / "Mulai antar" (demo), the walk is animated.
class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends ConsumerState<RouteScreen> with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _walk = AnimationController(vsync: this, duration: const Duration(seconds: 12))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _arrive();
    });
  var _stage = _Stage.plan;

  late LatLng _from = _start();
  var _hasFix = false;
  WalkRoute? _route;
  var _routing = true;
  StreamSubscription<LatLng>? _track;

  /// Progress from live GPS (fraction of the path); the animation drives it otherwise.
  double? _gpsT;

  /// Last live GPS fix while walking, where "Kamu" is drawn (not its projection onto the route).
  LatLng? _gpsPos;

  String get _id => widget.conversationId;

  /// Where the trip ends: the delivery address, or the pickup point.
  static LatLng _dest(ReservationInfo r) => r.delivery?.position ?? r.listing.position;

  /// Where it starts without GPS: the food's pickup point for a delivery (the provider's kitchen), else the chosen area.
  LatLng _start() {
    final r = ref.read(reservationProvider(widget.conversationId));
    return r?.delivery != null ? r!.listing.position : ref.read(locationProvider).position;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    _track?.cancel();
    _walk.dispose();
    super.dispose();
  }

  /// Opening the route is the request for the user's position: read GPS once (quietly), then ask for the route.
  Future<void> _prepare() async {
    final r = ref.read(reservationProvider(_id));
    if (r == null) return;
    final dest = _dest(r);
    final fix = await ref.read(deviceLocatorProvider).locate();
    if (!mounted) return;
    if (fix case LocationFound(:final position)) {
      ref.read(lastFixProvider.notifier).state = position;
      setState(() {
        _from = position;
        _hasFix = true;
      });
    }
    final route = await ref.read(routePlannerProvider).walk(_from, dest);
    if (!mounted) return;
    setState(() {
      _route = route;
      _routing = false;
    });
    if (_stage == _Stage.plan) _fit(_path(dest));
  }

  List<LatLng> _path(LatLng dest) => (_route ?? estimatedRoute(_from, dest)).path;

  void _fit(List<LatLng> path) {
    final top = MediaQuery.paddingOf(context).top;
    _map.fitCamera(CameraFit.coordinates(coordinates: path, padding: EdgeInsets.fromLTRB(96, top + 120, 96, 470), maxZoom: 17));
  }

  /// Live GPS when a position was found, else the animation. [demo] forces the animation (long press).
  void _begin({bool demo = false}) {
    setState(() => _stage = _Stage.walking);
    if (_hasFix && !demo) {
      _gpsT = 0;
      _track = ref.read(deviceLocatorProvider).track().listen(_onPosition);
    } else {
      _walk.forward(from: 0);
    }
  }

  void _onPosition(LatLng pos) {
    final r = ref.read(reservationProvider(_id));
    if (r == null || _stage != _Stage.walking) return;
    if (const Distance()(pos, _dest(r)) <= 30) {
      _arrive();
      return;
    }
    setState(() {
      _gpsPos = pos;
      _gpsT = progressAlong(_path(_dest(r)), pos);
    });
  }

  void _stop() {
    _track?.cancel();
    _track = null;
    _gpsT = null;
    _gpsPos = null;
    _walk.stop();
    _walk.value = 0;
    setState(() => _stage = _Stage.plan);
  }

  void _arrive() {
    _track?.cancel();
    _track = null;
    HapticFeedback.mediumImpact();
    setState(() => _stage = _Stage.arrived);
    final r = ref.read(reservationProvider(_id));
    // Put the pin in the free area above the sheet rather than at the screen centre.
    if (r != null) _map.move(_dest(r), 17.6, offset: const Offset(0, -190));
  }

  void _chat() => context.canPop() ? context.pop() : context.go('/chat/$_id');

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reservationProvider(_id));
    if (r == null) return const NotFoundScaffold();
    final dest = _dest(r);
    final delivering = r.delivery != null;
    final route = _route ?? estimatedRoute(_from, dest);
    final path = route.path;
    final total = route.meters;
    final tiles = ref.watch(tilesEnabledProvider);
    final area = ref.watch(locationProvider).name;
    // Who waits at the other end: the provider for a pickup, the receiver for a delivery.
    final otherShort = delivering ? firstName(r.receiver.name) : shortName(r.provider.name);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _walk,
        builder: (context, _) {
          final t = _stage == _Stage.arrived ? 1.0 : (_gpsT ?? _walk.value);
          final me = pointAlong(path, t);
          return Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    // Keep both ends clear of the back button, the labels and the sheet.
                    initialCameraFit: CameraFit.coordinates(coordinates: path, padding: EdgeInsets.fromLTRB(96, top + 120, 96, 470), maxZoom: 17),
                    maxZoom: 18,
                    backgroundColor: AppColors.mapSand,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    if (tiles) pawonTileLayer(),
                    if (_stage == _Stage.arrived)
                      PolygonLayer(polygons: [
                        Polygon(
                          points: circlePoints(dest, 30),
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderColor: AppColors.primaryDark,
                          borderStrokeWidth: 2.5,
                          pattern: StrokePattern.dashed(segments: const [8, 6]),
                        ),
                      ]),
                    PolylineLayer(polylines: [
                      Polyline(points: path, strokeWidth: 12, color: AppColors.surface),
                      Polyline(points: remainingPath(path, t), strokeWidth: 6, color: AppColors.primary),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: dest,
                        width: 180,
                        height: 92,
                        alignment: Alignment.topCenter,
                        // Bottom-aligned: the marker's bottom edge is the point, so the pin's tip must end exactly there.
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          MapLabel(_stage == _Stage.arrived ? 'Kamu sudah sampai' : (delivering ? r.receiver.name : r.provider.name), outlined: true),
                          const SizedBox(height: 6),
                          SvgPicture.string(teardropSvg('#2F5D39', scale: 1.3), semanticsLabel: delivering ? 'Alamat antar' : 'Titik ambil'),
                        ]),
                      ),
                      if (_stage != _Stage.arrived)
                        Marker(
                          // The real fix while walking with GPS; `me` is that fix projected onto the route (progress only).
                          point: _gpsPos ?? me,
                          width: 120,
                          height: 92,
                          // Dot centre sits on the point: 32 + 14 = 46 = half of 92.
                          child: const Column(children: [
                            SizedBox(height: 32),
                            SizedBox(width: 28, height: 28, child: UserDot()),
                            SizedBox(height: 4),
                            MapLabel('Kamu'),
                          ]),
                        ),
                    ]),
                    const OsmCredit(bottom: 360),
                  ],
                ),
              ),
              if (_stage == _Stage.walking)
                Positioned(top: top + 12, left: 16, right: 16, child: FadeSlideIn(child: _InstructionCard(route: route, t: t, delivering: delivering)))
              else
                Positioned(top: top + 8, left: 16, child: RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', shadow: true, onTap: _chat)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Sheet(
                  child: FadeSwitch(
                    child: switch (_stage) {
                      _Stage.plan => _PlanBody(
                          key: const ValueKey('plan'),
                          info: r,
                          from: _hasFix ? 'Lokasi kamu saat ini' : (delivering ? r.listing.pickupPoint : 'Lokasi kamu · $area'),
                          note: _routing ? 'Mencari rute jalan...' : (route.fromStreets ? null : 'Rute perkiraan · jalan belum termuat'),
                          meters: total,
                          otherShort: otherShort,
                          onChat: _chat,
                          onStart: _begin,
                          onDemoStart: () => _begin(demo: true),
                        ),
                      _Stage.walking => _WalkBody(key: const ValueKey('walk'), info: r, left: total * (1 - t), t: t, onChat: _chat, onStop: _stop),
                      // The receiver scans the provider's QR; the provider who delivered opens it.
                      _Stage.arrived => _ArrivedBody(key: const ValueKey('arrived'), info: r, otherShort: otherShort, onChat: _chat, onAction: () => context.push(delivering ? '/qr/$_id' : '/scan/$_id')),
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- pieces ----------

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            // With motion reduced the sheet just resizes: a zero-duration AnimatedSize asserts when its child changes size.
            if (Motion.reduced(context)) child else AnimatedSize(duration: Motion.slow, curve: Motion.move, alignment: Alignment.bottomCenter, child: child),
          ],
        ),
      );
}

class _ChatAndAction extends StatelessWidget {
  const _ChatAndAction({required this.onChat, required this.action});

  final VoidCallback onChat;
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(children: [
        AppButton(label: 'Chat', icon: LucideIcons.messageSquare, iconOnly: true, expand: false, variant: AppButtonVariant.outline, onPressed: onChat),
        const SizedBox(width: 12),
        Expanded(child: action),
      ]);
}

/// What changes hands at the end of the trip: the receiver pays on a pickup, the provider receives on a delivery.
String _payTitle(ReservationInfo r) {
  if (r.total == 0) return 'Gratis';
  if (r.pickup.paid) return 'Lunas';
  return r.delivery == null ? 'Bayar ${formatRupiah(r.payable)}' : 'Terima ${formatRupiah(r.payable)}';
}

String _payCaption(ReservationInfo r) {
  if (r.total == 0) return 'tidak perlu bayar';
  if (r.pickup.paid) return 'via QRIS';
  if (r.delivery == null) return 'di tempat saat ambil';
  return r.pickup.payMethod == null ? 'belum pilih cara bayar' : 'tunai saat sampai';
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({super.key, required this.info, required this.from, required this.meters, required this.otherShort, required this.onChat, required this.onStart, required this.onDemoStart, this.note});

  final ReservationInfo info;
  final String from;

  /// Route status under the title: still loading, or only an estimate.
  final String? note;
  final double meters;

  /// The provider (pickup) or the receiver (delivery), first name.
  final String otherShort;
  final VoidCallback onChat;
  final VoidCallback onStart;

  /// Long press on "Mulai jalan" / "Mulai antar": the animated walk, for demos.
  final VoidCallback onDemoStart;

  @override
  Widget build(BuildContext context) {
    final deadline = formatTime(info.pickup.deadline);
    final drop = info.delivery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(drop == null ? 'Rute jalan kaki' : 'Rute antar', style: AppTypography.titleL),
        if (note != null) ...[
          const SizedBox(height: 2),
          FadeSwitch(child: Text(note!, key: ValueKey(note), style: AppTypography.text(13, color: AppColors.inkMuted))),
        ],
        const SizedBox(height: 12),
        _Stop(icon: LucideIcons.circle, caption: 'Dari', title: from),
        Padding(padding: const EdgeInsets.only(left: 9), child: Column(children: [for (var i = 0; i < 3; i++) Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(vertical: 1.5), decoration: const BoxDecoration(color: AppColors.inkMuted, shape: BoxShape.circle))])),
        drop == null
            ? _Stop(icon: LucideIcons.mapPin, caption: 'Ke', title: info.provider.name, sub: '${info.listing.pickupPoint} · titik ambil')
            : _Stop(icon: LucideIcons.mapPin, caption: 'Ke', title: info.receiver.name, sub: '${drop.address} · alamat antar'),
        if (drop == null && info.listing.bringsContainer) ...[const SizedBox(height: 10), PackagingNote(info.listing.packaging, compact: true)],
        const Divider(height: 24),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill(formatDistance(meters), icon: LucideIcons.personStanding, height: 32, size: 13, weight: 700),
          Pill('± ${walkMinutes(meters)} mnt', height: 32, size: 13, weight: 700),
          Pill(drop == null ? 'Direservasi s/d $deadline' : 'Diantar s/d $deadline', fill: AppColors.successTint, color: AppColors.primaryDark, height: 32, size: 13, weight: 700),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surfaceSand, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
              child: const Icon(LucideIcons.scan, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(drop == null ? 'Pindai QR di HP $otherShort' : 'Tunjukkan QR ke $otherShort', style: AppTypography.text(13, color: AppColors.inkMuted)),
                Text('Berlaku s/d $deadline', style: AppTypography.display(17, weight: 700, height: 22)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_payTitle(info), style: AppTypography.text(15, weight: 700)),
              Text(_payCaption(info), style: AppTypography.text(13, color: AppColors.inkMuted)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        _ChatAndAction(
          onChat: onChat,
          action: Semantics(
            onLongPressHint: 'Demo jalan tanpa GPS',
            child: GestureDetector(onLongPress: onDemoStart, child: AppButton(label: drop == null ? 'Mulai jalan' : 'Mulai antar', onPressed: onStart)),
          ),
        ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.caption, required this.title, this.sub});

  final IconData icon;
  final String caption;
  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 14), child: Icon(icon, size: 22, color: AppColors.primaryDark)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(caption, style: AppTypography.text(13, color: AppColors.inkMuted)),
            Text(title, style: AppTypography.display(16, weight: 700, height: 22)),
            if (sub != null) Text(sub!, style: AppTypography.text(13, color: AppColors.inkMuted)),
          ]),
        ),
      ]);
}

class _WalkBody extends StatelessWidget {
  const _WalkBody({super.key, required this.info, required this.left, required this.t, required this.onChat, required this.onStop});

  final ReservationInfo info;
  final double left;
  final double t;
  final VoidCallback onChat;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final drop = info.delivery;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sisa ${formatDistance(left)} · ± ${walkMinutes(left)} mnt', style: AppTypography.titleL),
          const SizedBox(height: 4),
          Text(drop == null ? 'ke ${info.provider.name} · ${info.listing.pickupPoint}' : 'ke ${info.receiver.name} · ${drop.address}', style: AppTypography.text(14, color: AppColors.inkMuted)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: t, minHeight: 8, color: AppColors.primary, backgroundColor: AppColors.surfaceSand),
          ),
          const SizedBox(height: 14),
          Pill('${drop == null ? 'Pindai' : 'Tunjukkan'} QR s/d ${formatTime(info.pickup.deadline)}', height: 30, size: 13, weight: 700),
          const SizedBox(height: 16),
          _ChatAndAction(onChat: onChat, action: AppButton(label: 'Akhiri rute', variant: AppButtonVariant.outline, onPressed: onStop)),
        ],
      );
  }
}

class _ArrivedBody extends ConsumerWidget {
  const _ArrivedBody({super.key, required this.info, required this.otherShort, required this.onChat, required this.onAction});

  final ReservationInfo info;

  /// The provider (pickup) or the receiver (delivery), first name.
  final String otherShort;
  final VoidCallback onChat;

  /// "Pindai QR" for the receiver, "Buka QR ambil" for the provider who delivered.
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drop = info.delivery;
    final pay = info.total == 0
        ? ''
        : info.pickup.paid
            ? ' Sudah lunas via QRIS.'
            : drop == null
                ? ' Bayar ${formatRupiah(info.payable)} di tempat.'
                : info.pickup.payMethod == null
                    ? ' $otherShort belum memilih cara bayar.'
                    : ' Terima ${formatRupiah(info.payable)} tunai.';
    final deadline = formatTime(info.pickup.deadline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const CheckBurst(size: 36),
          const SizedBox(width: 4),
          Expanded(child: Text('Kamu sudah sampai', style: AppTypography.titleL)),
        ]),
        Text(drop == null ? 'Minta $otherShort membuka QR, lalu pindai.$pay' : 'Buka QR ambil, lalu minta $otherShort memindainya.$pay', style: AppTypography.text(15, height: 22)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surfaceSand, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Container(
              width: 128,
              height: 128,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              child: Stack(alignment: Alignment.center, children: [
                const ScanFrame(size: 64, color: AppColors.primaryDark, stroke: 3, corner: 18),
                Container(width: 20, height: 20, color: AppColors.primaryDark),
              ]),
            ),
            const SizedBox(height: 12),
            Countdown(
              until: info.pickup.deadline,
              now: ref.read(clockProvider),
              builder: (_, left) => Text('Berlaku s/d $deadline · sisa ${formatMinutesLeft(left)}', style: AppTypography.display(16, weight: 700, height: 22)),
            ),
            Text(drop == null ? 'Setelah dipindai, kamu langsung bisa beri ulasan.' : 'Setelah dipindai, poinmu langsung bertambah.', style: AppTypography.text(13, color: AppColors.inkMuted)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(LucideIcons.mapPin, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(drop == null ? '${info.provider.name} · ${info.listing.pickupPoint}' : '${info.receiver.name} · ${drop.address}', style: AppTypography.text(14, color: AppColors.inkMuted))),
        ]),
        if (drop == null && info.listing.bringsContainer) ...[const SizedBox(height: 10), PackagingNote(info.listing.packaging, compact: true)],
        const SizedBox(height: 16),
        _ChatAndAction(
          onChat: onChat,
          action: drop == null
              ? AppButton(label: 'Pindai QR', icon: LucideIcons.scanLine, onPressed: onAction)
              : AppButton(label: 'Buka QR ambil', icon: LucideIcons.qrCode, onPressed: onAction),
        ),
      ],
    );
  }
}

/// Dark turn-by-turn card on top of the map while walking (B8c): the next turn of the route, how far it is, and the
/// straight bit after it.
class _InstructionCard extends StatelessWidget {
  const _InstructionCard({required this.route, required this.t, required this.delivering});

  final WalkRoute route;
  final double t;

  /// Heading for the delivery address rather than the pickup point.
  final bool delivering;

  static IconData _icon(TurnKind k) => switch (k) {
        TurnKind.left || TurnKind.sharpLeft => LucideIcons.cornerUpLeft,
        TurnKind.right || TurnKind.sharpRight => LucideIcons.cornerUpRight,
        TurnKind.slightLeft => LucideIcons.arrowUpLeft,
        TurnKind.slightRight => LucideIcons.arrowUpRight,
        TurnKind.uturn => LucideIcons.undo2,
        TurnKind.arrive => LucideIcons.flag,
        TurnKind.depart || TurnKind.straight => LucideIcons.arrowUp,
      };

  @override
  Widget build(BuildContext context) {
    final total = pathLength(route.path);
    final walked = total * t;
    RouteStep? next;
    for (final s in route.steps) {
      if (s.turn != TurnKind.depart && s.startsAt > walked + 1) {
        next = s;
        break;
      }
    }
    final toTurn = (next?.startsAt ?? total) - walked;
    final last = next == null || next.turn == TurnKind.arrive;
    final turn = last ? 'Lurus sampai ${delivering ? 'alamat antar' : 'titik ambil'}' : next.instruction;
    final icon = last ? LucideIcons.arrowUp : _icon(next.turn);
    final after = last || next.length <= 0 ? null : 'Lalu lurus ${formatDistance(next.length)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))]),
      child: Row(children: [
        Icon(icon, size: 40, color: AppColors.background),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(formatDistance(math.max(0, toTurn)), style: AppTypography.display(26, height: 32, color: AppColors.background)),
            Text(turn, style: AppTypography.text(15, weight: 700, color: AppColors.background)),
            if (after != null) Text(after, style: AppTypography.text(13, color: AppColors.onGreenMuted)),
          ]),
        ),
      ]),
    );
  }
}
