import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/pickup_points_repository.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/services/formatters.dart';
import '../../core/services/geo.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pawon_map.dart';

/// C15d "Pilih lokasi di peta": drag the map under a fixed pin (it lifts while dragging and drops on release),
/// or search a place. Returns the picked [PickupPoint] (for this listing only); "Simpan ke titik tersimpan" also
/// saves it. The map starts at the phone's GPS position when it can be read (else the demo point near Kos Melati);
/// the address comes from the platform geocoder, or the nearest known place within 300 m.
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key});

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  final _map = MapController();
  final _name = TextEditingController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  /// The latest real GPS position; null until one is read.
  late LatLng? _gps = ref.read(lastFixProvider);
  late var _center = _gps ?? gpsPoint.position;
  var _dragging = false;
  var _save = false;
  var _locating = false;
  var _confirming = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    // Opening this screen ("Mulai dari GPS") is the user's request for their position; a failure here stays quiet
    // and the map keeps the demo point. "Ke lokasi saya" reports problems.
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate(report: false));
  }

  Future<void> _locate({required bool report}) async {
    if (_locating) return;
    setState(() => _locating = true);
    final locator = ref.read(deviceLocatorProvider);
    final fix = await locator.locate();
    if (!mounted) return;
    setState(() => _locating = false);
    switch (fix) {
      case LocationFound(:final position):
        ref.read(lastFixProvider.notifier).state = position;
        _gps = position;
        _goTo(position);
      case LocationProblem(:final issue):
        if (report) showLocationProblem(context, issue, locator);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// The closest known place, only when it is close enough (300 m) to name the pin.
  PickupPoint? get _nearest {
    var best = searchablePlaces.first;
    for (final p in searchablePlaces) {
      if (distanceMeters(_center, p.position) < distanceMeters(_center, best.position)) best = p;
    }
    return distanceMeters(_center, best.position) <= 300 ? best : null;
  }

  void _goTo(LatLng p) {
    _map.move(p, 17.5);
    setState(() => _center = p);
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    final near = _nearest;
    String address;
    if (near != null) {
      address = near.name;
    } else {
      setState(() => _confirming = true);
      address = await ref.read(deviceLocatorProvider).address(_center) ?? 'Titik di peta';
      if (!mounted) return;
      setState(() => _confirming = false);
    }
    final name = _name.text.trim();
    var point = PickupPoint(id: 'map_${_center.latitude}_${_center.longitude}', name: name.isEmpty ? address : name, address: address, position: _center, fromMap: true);
    if (_save) {
      final saved = ref.read(pickupPointsProvider.notifier).save(point);
      point = PickupPoint(id: saved.id, name: saved.name, address: saved.address, position: saved.position, fromMap: true);
    }
    context.pop(point);
  }

  @override
  Widget build(BuildContext context) {
    final near = _nearest;
    final fromGps = distanceMeters(_center, _gps ?? gpsPoint.position);
    final area = nearbyAreaName(_center);
    final top = MediaQuery.paddingOf(context).top;
    final query = _search.text.trim().toLowerCase();
    final results = query.isEmpty ? searchablePlaces : [for (final p in searchablePlaces) if ('${p.name} ${p.address}'.toLowerCase().contains(query)) p];
    final tiles = ref.watch(tilesEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.mapSand,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerDown: (_) => setState(() => _dragging = true),
                    onPointerUp: (_) => setState(() => _dragging = false),
                    onPointerCancel: (_) => setState(() => _dragging = false),
                    child: FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: 17.5,
                        minZoom: 14,
                        maxZoom: 18,
                        backgroundColor: AppColors.mapSand,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                        onPositionChanged: (camera, _) => setState(() => _center = camera.center),
                      ),
                      children: [if (tiles) pawonTileLayer(), const OsmCredit()],
                    ),
                  ),
                ),
                // The pin stays in the middle; the map moves under it.
                Center(
                  child: IgnorePointer(
                    child: AnimatedSlide(
                      offset: Offset(0, _dragging ? -0.08 : 0),
                      duration: Motion.of(context, Motion.fast),
                      curve: _dragging ? Motion.enter : Motion.pop,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const MapLabel('Titik ambil', outlined: true),
                        const SizedBox(height: 6),
                        SvgPicture.string(teardropSvg('#2F5D39', scale: 1.4), semanticsLabel: 'Pin titik ambil'),
                        // Lift the tip so it, not the box centre, marks the spot.
                        const SizedBox(height: 74),
                      ]),
                    ),
                  ),
                ),
                Positioned(
                  top: top + 8,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Row(children: [
                        RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', shadow: true, onTap: () => context.pop()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
                            ),
                            child: TextField(
                              controller: _search,
                              focusNode: _searchFocus,
                              onChanged: (_) => setState(() {}),
                              style: AppTypography.text(16),
                              cursorColor: AppColors.primary,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                prefixIcon: const Icon(LucideIcons.search, color: AppColors.inkMuted),
                                hintText: 'Cari alamat atau tempat',
                                hintStyle: AppTypography.text(16, color: AppColors.inkMuted),
                                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                            ),
                          ),
                        ),
                      ]),
                      AnimatedSize(
                        duration: Motion.of(context, Motion.base),
                        curve: Motion.move,
                        child: _searchFocus.hasFocus && results.isNotEmpty
                            ? Container(
                                margin: const EdgeInsets.only(top: 8, left: 56),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
                                ),
                                child: Column(children: [
                                  for (final p in results)
                                    ListTile(
                                      minTileHeight: 52,
                                      leading: const Icon(LucideIcons.mapPin, color: AppColors.primary),
                                      title: Text(p.name, style: AppTypography.text(15, weight: 600)),
                                      subtitle: Text(p.address, style: AppTypography.text(13, color: AppColors.inkMuted)),
                                      onTap: () {
                                        _search.text = p.name;
                                        _searchFocus.unfocus();
                                        _goTo(p.position);
                                      },
                                    ),
                                ]),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: RoundIconButton(icon: LucideIcons.navigation, semanticLabel: 'Ke lokasi saya', size: 52, shadow: true, onTap: _locating ? null : () => _locate(report: true)),
                ),
              ],
            ),
          ),
          // The panel scrolls and is capped, so the name field and the confirm button stay reachable with the keyboard open.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 14),
                    Text('Geser peta untuk memindahkan pin', style: AppTypography.text(13, weight: 600, color: AppColors.inkMuted)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(color: AppColors.successTint, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.mapPin, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FadeSwitch(
                          child: Column(
                            key: ValueKey(near?.id ?? 'map'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(near?.name ?? 'Titik di peta', style: AppTypography.display(18, weight: 700, height: 24)),
                              Text('${area == null ? '' : '$area · '}± ${formatDistance(fromGps)} dari GPS', style: AppTypography.text(13, color: AppColors.inkMuted)),
                            ],
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Nama titik (opsional)', controller: _name, hint: 'Contoh: Depan kos', textCapitalization: TextCapitalization.sentences),
                    const SizedBox(height: 4),
                    AppCheckbox(value: _save, label: 'Simpan ke titik tersimpan', onChanged: (v) => setState(() => _save = v)),
                    const SizedBox(height: 8),
                    const InfoBox('Alamat lengkap hanya tampil ke penerima setelah reservasi diterima.'),
                    const SizedBox(height: 16),
                    AppButton(label: 'Pilih lokasi ini', loading: _confirming, onPressed: _confirm),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
