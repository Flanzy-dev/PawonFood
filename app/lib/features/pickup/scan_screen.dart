import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/motion_widgets.dart';
import '../../core/motion/success_flood.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/countdown.dart';
import '../../core/widgets/listing_summary.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/top_bar.dart';

/// B10b Pindai QR (receiver). Live camera with a viewfinder; decoding is simulated: the provider's QR "appears"
/// after [simulatedScanDelayProvider] (tap the preview to scan right away). A scan inside the pickup window marks
/// the food picked up and opens the review; a late scan expires the reservation (B10c).
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  late final AppCamera _camera = ref.read(cameraFactoryProvider)();
  var _cameraReady = false;
  var _found = false;
  var _alreadyScanned = false;
  Timer? _timer;
  final _frame = GlobalKey();

  /// Last reservation seen, so the scanner keeps its look while the flood covers it after the scan.
  ReservationInfo? _last;

  String get _id => widget.conversationId;

  @override
  void initState() {
    super.initState();
    unawaited(_startCamera());
    _timer = Timer(ref.read(simulatedScanDelayProvider), _detected);
  }

  Future<void> _startCamera() async {
    CameraStatus status;
    try {
      status = await _camera.start();
    } catch (_) {
      status = CameraStatus.unavailable; // no camera plugin (tests) or no device camera: keep the dark preview
    }
    if (mounted) setState(() => _cameraReady = status == CameraStatus.ready);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_camera.dispose());
    super.dispose();
  }

  Future<void> _detected() async {
    if (_found || !mounted) return;
    _timer?.cancel();
    setState(() => _found = true);
    unawaited(HapticFeedback.mediumImpact());
    final outcome = ref.read(chatProvider.notifier).scanQr(_id);
    // One QR, one scan: a second scan must not replay the success and the review.
    if (outcome == ScanOutcome.alreadyUsed) setState(() => _alreadyScanned = true);
    if (outcome == ScanOutcome.ok) {
      // A beat on "QR terbaca", then green grows out of the viewfinder and opens onto the review.
      await Future<void>.delayed(Motion.of(context, Motion.base));
      if (!mounted) return;
      final box = _frame.currentContext?.findRenderObject() as RenderBox?;
      final origin = box != null && box.hasSize ? box.localToGlobal(box.size.center(Offset.zero)) : MediaQuery.sizeOf(context).center(Offset.zero);
      final router = GoRouter.of(context);
      await playSuccessFlood(context, origin: origin, whileCovered: () => unawaited(router.pushReplacement('/review/$_id')));
      return;
    }
    // No success colour on the way to "Reservasi kedaluwarsa".
    await Future<void>.delayed(Motion.of(context, const Duration(milliseconds: 700)));
    if (!mounted) return;
    if (outcome == ScanOutcome.expired) {
      context.pushReplacement('/expired/$_id');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reservationProvider(_id)) ?? _last;
    _last = r;
    if (r == null) return const Scaffold(backgroundColor: AppColors.cameraBg, body: SizedBox.shrink());
    final providerShort = shortName(r.provider.name);
    final frameColor = _found ? AppColors.detectBox : AppColors.successTint;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.cameraBg,
        body: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Pindai QR', close: true, dark: true, fallback: '/messages'),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    button: true,
                    label: 'Arahkan kamera ke QR $providerShort',
                    child: GestureDetector(
                      onTap: _detected,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: AppColors.cameraControl, child: _cameraReady ? _camera.buildPreview() : const SizedBox.shrink()),
                            Center(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                AnimatedSwitcher(
                                  duration: Motion.of(context, Motion.base),
                                  child: Pill(
                                    _alreadyScanned ? 'QR sudah dipindai' : _found ? 'QR terbaca' : 'Arahkan ke QR $providerShort',
                                    key: ValueKey('$_found$_alreadyScanned'),
                                    fill: _found ? AppColors.detectBox : AppColors.surface,
                                    color: AppColors.primaryDark,
                                    height: 34,
                                    size: 14,
                                    weight: 700,
                                    hPad: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // 260 dp on a normal phone; smaller where the preview area is short (large text, small phones).
                                Builder(builder: (context) {
                                  final side = math.min(260.0, MediaQuery.sizeOf(context).shortestSide * 0.7);
                                  return SizedBox(
                                  key: _frame,
                                  width: side,
                                  height: side,
                                  child: Stack(alignment: Alignment.center, children: [
                                    TweenAnimationBuilder<Color?>(
                                      tween: ColorTween(end: frameColor),
                                      duration: Motion.of(context, Motion.base),
                                      builder: (_, c, _) => ScanFrame(size: side, color: c ?? frameColor, stroke: 5, corner: 58 * side / 260),
                                    ),
                                    if (!_found) SizedBox(width: side - 40, height: side - 40, child: const ScanLine(child: SizedBox.expand())),
                                  ]),
                                );
                                }),
                              ]),
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Countdown(
                                until: r.pickup.deadline,
                                now: ref.read(clockProvider),
                                builder: (_, left) => Pill('Sisa ${formatMinutesLeft(left)}', fill: AppColors.primaryDark, color: AppColors.detectBox, height: 30, size: 13, weight: 700),
                              ),
                            ),
                            const Positioned(left: 16, bottom: 16, child: Pill('Pratinjau kamera', fill: Color(0xC7111A15), color: AppColors.surfaceSand, height: 32, size: 14, weight: 500, hPad: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ListingSummaryCard(listing: r.listing, dark: true, subtitle: '${r.provider.name} · ambil s/d ${formatTime(r.pickup.deadline)}'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text('QR hanya berlaku untuk reservasimu dan sampai batas waktu ambil.', textAlign: TextAlign.center, style: AppTypography.text(13, color: AppColors.cameraText)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
