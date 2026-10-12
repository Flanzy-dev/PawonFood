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
import '../../core/data/session_repository.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/motion_widgets.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/countdown.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pawon_map.dart';
import '../../core/widgets/pills.dart';

enum _Stage { plan, walking, arrived }

/// B8b Rute ke titik ambil → B8c Dalam perjalanan → B8d Sudah sampai. Walking only; the walk is simulated along a
/// street-like path from the user's location to the pickup point.
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

  String get _id => widget.conversationId;

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _stage = _Stage.walking);
    _walk.forward(from: 0);
  }

  void _stop() {
    _walk.stop();
    _walk.value = 0;
    setState(() => _stage = _Stage.plan);
  }

  void _arrive() {
    HapticFeedback.mediumImpact();
    setState(() => _stage = _Stage.arrived);
    final r = ref.read(reservationProvider(_id));
    // Put the pin in the free area above the sheet rather than at the screen centre.
    if (r != null) _map.move(r.listing.position, 17.6, offset: const Offset(0, -190));
  }

  void _chat() => context.canPop() ? context.pop() : context.go('/chat/$_id');

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reservationProvider(_id));
    if (r == null) return const NotFoundScaffold();
    final start = ref.watch(locationProvider).position;
    final dest = r.listing.position;
    final path = _streetPath(start, dest);
    final total = _length(path);
    final tiles = ref.watch(tilesEnabledProvider);
    final user = ref.watch(sessionProvider);
    final providerShort = shortName(r.provider.name);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _walk,
        builder: (context, _) {
          final t = _stage == _Stage.arrived ? 1.0 : _walk.value;
          final me = _pointAt(path, t);
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
                      Polyline(points: _rest(path, t), strokeWidth: 6, color: AppColors.primary),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: dest,
                        width: 180,
                        height: 92,
                        alignment: Alignment.topCenter,
                        child: Column(children: [
                          MapLabel(_stage == _Stage.arrived ? 'Kamu sudah sampai' : r.provider.name, outlined: true),
                          const SizedBox(height: 6),
                          SvgPicture.string(teardropSvg('#2F5D39', scale: 1.3), semanticsLabel: 'Titik ambil'),
                        ]),
                      ),
                      if (_stage != _Stage.arrived)
                        Marker(
                          point: me,
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
                Positioned(top: top + 12, left: 16, right: 16, child: FadeSlideIn(child: _InstructionCard(path: path, t: t)))
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
                          from: 'Lokasi kamu · ${user?.pickupPoint ?? 'Pogung'}',
                          meters: total,
                          providerShort: providerShort,
                          onChat: _chat,
                          onStart: _start,
                        ),
                      _Stage.walking => _WalkBody(key: const ValueKey('walk'), info: r, left: total * (1 - t), t: t, onChat: _chat, onStop: _stop),
                      _Stage.arrived => _ArrivedBody(key: const ValueKey('arrived'), info: r, providerShort: providerShort, onChat: _chat, onScan: () => context.push('/scan/$_id')),
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

// ---------- geometry ----------

/// Start → east → north → east, like walking along the kampung streets.
List<LatLng> _streetPath(LatLng a, LatLng b) {
  final midLng = a.longitude + (b.longitude - a.longitude) * 0.55;
  return [a, LatLng(a.latitude, midLng), LatLng(b.latitude, midLng), b];
}

const _distance = Distance();

double _length(List<LatLng> p) {
  var d = 0.0;
  for (var i = 1; i < p.length; i++) {
    d += _distance(p[i - 1], p[i]);
  }
  return d;
}

/// Point at fraction [t] of the path's length.
LatLng _pointAt(List<LatLng> p, double t) {
  var left = _length(p) * t;
  for (var i = 1; i < p.length; i++) {
    final seg = _distance(p[i - 1], p[i]);
    if (left <= seg || i == p.length - 1) {
      final f = seg == 0 ? 0.0 : (left / seg).clamp(0.0, 1.0);
      return LatLng(p[i - 1].latitude + (p[i].latitude - p[i - 1].latitude) * f, p[i - 1].longitude + (p[i].longitude - p[i - 1].longitude) * f);
    }
    left -= seg;
  }
  return p.last;
}

/// The part still to walk, from the user's position to the end.
List<LatLng> _rest(List<LatLng> p, double t) {
  final here = _pointAt(p, t);
  var walked = _length(p) * t;
  for (var i = 1; i < p.length; i++) {
    final seg = _distance(p[i - 1], p[i]);
    if (walked <= seg) return [here, ...p.sublist(i)];
    walked -= seg;
  }
  return [p.last];
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
            AnimatedSize(duration: Motion.of(context, Motion.slow), curve: Motion.move, alignment: Alignment.bottomCenter, child: child),
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

String _payTitle(ReservationInfo r) => r.amount == 0 ? 'Gratis' : r.pickup.paid ? 'Lunas' : 'Bayar ${formatRupiah(r.amount)}';

String _payCaption(ReservationInfo r) => r.amount == 0 ? 'tidak perlu bayar' : r.pickup.paid ? 'via QRIS' : 'di tempat saat ambil';

class _PlanBody extends StatelessWidget {
  const _PlanBody({super.key, required this.info, required this.from, required this.meters, required this.providerShort, required this.onChat, required this.onStart});

  final ReservationInfo info;
  final String from;
  final double meters;
  final String providerShort;
  final VoidCallback onChat;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final deadline = formatTime(info.pickup.deadline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rute jalan kaki', style: AppTypography.titleL),
        const SizedBox(height: 12),
        _Stop(icon: LucideIcons.circle, caption: 'Dari', title: from),
        Padding(padding: const EdgeInsets.only(left: 9), child: Column(children: [for (var i = 0; i < 3; i++) Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(vertical: 1.5), decoration: const BoxDecoration(color: AppColors.inkMuted, shape: BoxShape.circle))])),
        _Stop(icon: LucideIcons.mapPin, caption: 'Ke', title: info.provider.name, sub: '${info.listing.pickupPoint} · titik ambil'),
        const Divider(height: 24),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill(formatDistance(meters), icon: LucideIcons.personStanding, height: 32, size: 13, weight: 700),
          Pill('± ${walkMinutes(meters)} mnt', height: 32, size: 13, weight: 700),
          Pill('Direservasi s/d $deadline', fill: AppColors.successTint, color: AppColors.primaryDark, height: 32, size: 13, weight: 700),
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
                Text('Pindai QR di HP $providerShort', style: AppTypography.text(13, color: AppColors.inkMuted)),
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
        _ChatAndAction(onChat: onChat, action: AppButton(label: 'Mulai jalan', onPressed: onStart)),
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sisa ${formatDistance(left)} · ± ${walkMinutes(left)} mnt', style: AppTypography.titleL),
          const SizedBox(height: 4),
          Text('ke ${info.provider.name} · ${info.listing.pickupPoint}', style: AppTypography.text(14, color: AppColors.inkMuted)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: t, minHeight: 8, color: AppColors.primary, backgroundColor: AppColors.surfaceSand),
          ),
          const SizedBox(height: 14),
          Pill('Pindai QR s/d ${formatTime(info.pickup.deadline)}', height: 30, size: 13, weight: 700),
          const SizedBox(height: 16),
          _ChatAndAction(onChat: onChat, action: AppButton(label: 'Akhiri rute', variant: AppButtonVariant.outline, onPressed: onStop)),
        ],
      );
}

class _ArrivedBody extends ConsumerWidget {
  const _ArrivedBody({super.key, required this.info, required this.providerShort, required this.onChat, required this.onScan});

  final ReservationInfo info;
  final String providerShort;
  final VoidCallback onChat;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pay = info.amount == 0 ? '' : info.pickup.paid ? ' Sudah lunas via QRIS.' : ' Bayar ${formatRupiah(info.amount)} di tempat.';
    final deadline = formatTime(info.pickup.deadline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const CheckBurst(size: 36),
          const SizedBox(width: 4),
          Expanded(child: Text('Kamu sudah sampai', style: AppTypography.titleL)),
        ]),
        Text('Minta $providerShort membuka QR, lalu pindai.$pay', style: AppTypography.text(15, height: 22)),
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
            Text('Setelah dipindai, kamu langsung bisa beri ulasan.', style: AppTypography.text(13, color: AppColors.inkMuted)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(LucideIcons.mapPin, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 8),
          Expanded(child: Text('${info.provider.name} · ${info.listing.pickupPoint}', style: AppTypography.text(14, color: AppColors.inkMuted))),
        ]),
        const SizedBox(height: 16),
        _ChatAndAction(onChat: onChat, action: AppButton(label: 'Pindai QR', icon: LucideIcons.scanLine, onPressed: onScan)),
      ],
    );
  }
}

/// Dark turn-by-turn card on top of the map while walking (B8c).
class _InstructionCard extends StatelessWidget {
  const _InstructionCard({required this.path, required this.t});

  final List<LatLng> path;
  final double t;

  @override
  Widget build(BuildContext context) {
    final total = _length(path);
    final walked = total * t;
    // Distance to the next corner, its turn direction and the straight bit after it.
    var acc = 0.0;
    var toTurn = total - walked;
    String turn = 'Lurus sampai titik ambil';
    IconData icon = LucideIcons.arrowUp;
    String? after;
    for (var i = 1; i < path.length - 1; i++) {
      acc += _distance(path[i - 1], path[i]);
      if (acc > walked) {
        toTurn = acc - walked;
        final a = path[i - 1], b = path[i], c = path[i + 1];
        final cross = (b.longitude - a.longitude) * (c.latitude - b.latitude) - (b.latitude - a.latitude) * (c.longitude - b.longitude);
        final left = cross > 0;
        turn = '${left ? 'Belok kiri' : 'Belok kanan'} ke ${i == 1 ? 'Jl. Pogung Lor' : 'Jl. Pogung Baru'}';
        icon = left ? LucideIcons.cornerUpLeft : LucideIcons.cornerUpRight;
        after = 'Lalu lurus ${formatDistance(_distance(b, c))}';
        break;
      }
    }
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
