import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/providers.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/food_validator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';
import 'share_state.dart';

enum _Phase { starting, scanning, ready, capturing, rejected, denied, unavailable }

/// Step 1 of 3 (C12–C14): live camera with the AI scan. Camera only, never a gallery picker.
/// Long-press the title to choose the simulated AI result (demo mode).
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with SingleTickerProviderStateMixin {
  late final AppCamera _camera = ref.read(cameraFactoryProvider)();
  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  Timer? _readyTimer;
  var _phase = _Phase.starting;
  ValidationResult? _rejection;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _scan.dispose();
    unawaited(_camera.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _phase = _Phase.starting);
    _apply(await _camera.start());
  }

  void _apply(CameraStatus status) {
    if (!mounted) return;
    switch (status) {
      case CameraStatus.ready:
        setState(() => _phase = _Phase.scanning);
        // Simulated live detection: the box appears shortly after the camera is ready.
        _readyTimer?.cancel();
        _readyTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted && _phase == _Phase.scanning) setState(() => _phase = _Phase.ready);
        });
      case CameraStatus.denied:
        setState(() => _phase = _Phase.denied);
      case CameraStatus.unavailable:
        setState(() => _phase = _Phase.unavailable);
    }
  }

  Future<void> _capture() async {
    if (_phase != _Phase.scanning && _phase != _Phase.ready) return;
    setState(() => _phase = _Phase.capturing);
    try {
      final path = await _camera.capture();
      final result = await ref.read(foodValidatorProvider).validate(path);
      if (!mounted) return;
      if (result.verdict == AiVerdict.rejected) {
        setState(() {
          _phase = _Phase.rejected;
          _rejection = result;
        });
        return;
      }
      ref.read(shareCaptureProvider.notifier).state = ShareCapture(photoPath: path, result: result);
      await context.push('/share/form');
      if (mounted) setState(() => _phase = _Phase.ready);
    } on Object {
      if (!mounted) return;
      setState(() => _phase = _Phase.ready);
      showAppSnack(context, 'Foto gagal diambil. Coba lagi.');
    }
  }

  Future<void> _flip() async {
    setState(() => _phase = _Phase.starting);
    _apply(await _camera.flip());
  }

  Future<void> _toggleFlash() async {
    await _camera.toggleFlash();
    if (mounted) setState(() {});
  }

  void _chooseDemoMode() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final mode = ref.watch(demoAiModeProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mode demo AI', style: AppTypography.titleL),
                  const SizedBox(height: 4),
                  Text('Memilih hasil simulasi validasi foto. Model YOLO asli menyusul.', style: AppTypography.bodyMuted),
                  const SizedBox(height: 8),
                  for (final m in DemoAiMode.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 52,
                      title: Text(m.label, style: AppTypography.text(16, weight: m == mode ? 700 : 500)),
                      trailing: m == mode ? const Icon(LucideIcons.check, color: AppColors.primary) : null,
                      onTap: () {
                        ref.read(demoAiModeProvider.notifier).state = m;
                        Navigator.of(ctx).pop();
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTips() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tips foto', style: AppTypography.titleL),
              const SizedBox(height: 12),
              for (final t in const ['Foto langsung dari kamera. Foto dari galeri atau internet tidak bisa dipakai.', 'Taruh makanan di tengah dan pastikan cahaya cukup.', 'Satu jenis makanan per foto supaya cepat dikenali AI.'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.check, size: 18, color: AppColors.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t, style: AppTypography.body)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  ({String label, bool error}) _liveDetection(DemoAiMode m) => switch (m) {
        DemoAiMode.normal || DemoAiMode.lowConfidence => (label: 'Lauk matang', error: false),
        DemoAiMode.rawIngredients => (label: 'Bahan mentah', error: false),
        DemoAiMode.notFood => (label: 'Bukan makanan', error: true),
      };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.cameraBg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + (bottom > 0 ? 0 : 0)),
            child: Column(
              children: [
                Row(children: [
                  RoundIconButton(icon: LucideIcons.x, semanticLabel: 'Tutup', fill: AppColors.cameraControl, borderColor: null, iconColor: AppColors.background, onTap: () => context.canPop() ? context.pop() : context.go('/')),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: _chooseDemoMode,
                      behavior: HitTestBehavior.opaque,
                      child: Semantics(
                        hint: 'Tekan lama untuk mode demo AI',
                        child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Langkah 1 dari 3', textAlign: TextAlign.center, style: AppTypography.text(17, weight: 700, color: AppColors.background))),
                      ),
                    ),
                  ),
                  RoundIconButton(
                    icon: _camera.flashOn ? LucideIcons.zap : LucideIcons.zapOff,
                    semanticLabel: 'Flash',
                    fill: AppColors.cameraControl,
                    borderColor: null,
                    iconColor: AppColors.background,
                    onTap: _phase == _Phase.denied || _phase == _Phase.unavailable ? null : _toggleFlash,
                  ),
                ]),
                const SizedBox(height: 10),
                const StepProgress(current: 1, dark: true),
                const SizedBox(height: 16),
                Expanded(child: _phase == _Phase.denied || _phase == _Phase.unavailable ? _blocked() : _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blocked() {
    final denied = _phase == _Phase.denied;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 88, height: 88, decoration: const BoxDecoration(color: AppColors.cameraControl, shape: BoxShape.circle), child: const Icon(LucideIcons.cameraOff, size: 40, color: AppColors.background)),
            const SizedBox(height: 20),
            Text(denied ? 'Izin kamera dibutuhkan' : 'Kamera tidak tersedia', textAlign: TextAlign.center, style: AppTypography.display(22, height: 28, color: AppColors.background)),
            const SizedBox(height: 8),
            Text(
              denied ? 'PawonFood hanya memakai kamera langsung untuk foto makanan. Foto dari galeri tidak bisa dipakai.' : 'Perangkat ini tidak punya kamera yang bisa dipakai untuk membagikan makanan.',
              textAlign: TextAlign.center,
              style: AppTypography.text(15, height: 22, color: AppColors.cameraText),
            ),
            const SizedBox(height: 24),
            if (denied) AppButton(label: 'Coba lagi', variant: AppButtonVariant.light, onPressed: _start),
            const SizedBox(height: 10),
            AppButton(label: 'Kembali', variant: AppButtonVariant.ghost, onPressed: () => context.canPop() ? context.pop() : context.go('/')),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final demo = ref.watch(demoAiModeProvider);
    final live = _liveDetection(demo);
    final rejected = _phase == _Phase.rejected;
    final scanning = _phase == _Phase.starting || _phase == _Phase.scanning || _phase == _Phase.capturing;
    final showBox = _phase == _Phase.ready || rejected;
    final error = rejected || (live.error && _phase == _Phase.ready);
    final label = rejected ? 'Bukan makanan' : live.label;
    final detected = _phase == _Phase.ready && !live.error;

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.cameraLine),
                if (_phase != _Phase.starting) _camera.buildPreview(),
                const ColoredBox(color: Color(0x2E111A15)),
                LayoutBuilder(
                  builder: (context, c) {
                    final side = c.maxWidth * 0.72;
                    final left = (c.maxWidth - side) / 2;
                    final top = c.maxHeight * 0.2;
                    return Stack(children: [
                      if (showBox) ...[
                        Positioned(
                          left: left,
                          top: top,
                          width: side,
                          height: side,
                          child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: error ? AppColors.error : AppColors.detectBox, width: 3))),
                        ),
                        Positioned(
                          left: left,
                          top: top - 36,
                          child: Pill(label, fill: error ? AppColors.error : AppColors.detectBox, color: error ? AppColors.background : AppColors.primaryDark, height: 32, size: 15, weight: 700, hPad: 14),
                        ),
                      ],
                      if (scanning)
                        AnimatedBuilder(
                          animation: _scan,
                          builder: (_, _) => Positioned(
                            left: 28,
                            right: 28,
                            top: c.maxHeight * (0.18 + 0.5 * _scan.value),
                            child: Container(height: 4, decoration: BoxDecoration(color: AppColors.detectBox, borderRadius: BorderRadius.circular(2), boxShadow: const [BoxShadow(color: AppColors.detectBox, blurRadius: 12)])),
                          ),
                        ),
                    ]);
                  },
                ),
                if (scanning) const Positioned(top: 16, left: 16, child: Pill('AI sedang memindai...', fill: AppColors.primaryDark, color: AppColors.background, height: 32, size: 14, hPad: 14)),
                const Positioned(left: 16, bottom: 16, child: Pill('Pratinjau kamera', fill: Color(0xC7111A15), color: AppColors.surfaceSand, height: 32, size: 14, weight: 500, hPad: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _status(rejected: rejected, detected: detected, notFoodLive: live.error && _phase == _Phase.ready),
        const SizedBox(height: 16),
        if (rejected)
          AppButton(label: 'Foto ulang', variant: AppButtonVariant.light, onPressed: () => setState(() => _phase = _Phase.ready))
        else
          _controls(),
      ],
    );
  }

  Widget _status({required bool rejected, required bool detected, required bool notFoodLive}) {
    Widget icon(IconData i, Color bg, Color fg) => Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(i, size: 24, color: fg));
    if (rejected) {
      return _statusRow(
        icon(LucideIcons.x, AppColors.errorLight, AppColors.cameraBg),
        _rejection?.message ?? msgNotFood,
        'Foto dari galeri atau internet tidak bisa dipakai.',
        AppColors.errorLight,
      );
    }
    if (detected) {
      return _statusRow(
        icon(LucideIcons.check, AppColors.successTint, AppColors.primary),
        'Makanan terdeteksi, siap difoto',
        'Foto hanya bisa diambil langsung dari kamera, bukan dari galeri. Ini yang bikin penerima percaya makananmu asli.',
        AppColors.background,
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notFoodLive ? 'Belum terlihat makanan' : 'Arahkan kamera ke makanan', style: AppTypography.display(22, height: 27, color: AppColors.background)),
          const SizedBox(height: 4),
          Text(notFoodLive ? 'Arahkan kamera ke makanan, ya.' : 'Pastikan makanan terlihat jelas dan cahaya cukup.', style: AppTypography.text(14, color: AppColors.cameraText)),
        ],
      ),
    );
  }

  Widget _statusRow(Widget icon, String title, String body, Color titleColor) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.display(19, height: 24, color: titleColor)),
                const SizedBox(height: 4),
                Text(body, style: AppTypography.text(13, height: 19, color: AppColors.cameraText)),
              ],
            ),
          ),
        ],
      );

  Widget _controls() {
    final busy = _phase == _Phase.capturing || _phase == _Phase.starting;
    Widget side(IconData icon, String label, VoidCallback onTap) => SizedBox(
          width: 88,
          child: Semantics(
            button: true,
            label: label,
            child: InkWell(
              onTap: busy ? null : onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 26, color: AppColors.background),
                  const SizedBox(height: 6),
                  Text(label, style: AppTypography.text(13, weight: 600, color: AppColors.background)),
                ]),
              ),
            ),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        side(LucideIcons.info, 'Tips foto', _showTips),
        Semantics(
          button: true,
          enabled: !busy,
          label: 'Ambil foto',
          child: GestureDetector(
            onTap: busy ? null : _capture,
            child: Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppColors.cameraBg, shape: BoxShape.circle),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: busy ? AppColors.cameraText : AppColors.background, shape: BoxShape.circle),
                  child: busy ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary)) : const PawonLogo(size: 36, color: AppColors.primary),
                ),
              ),
            ),
          ),
        ),
        side(LucideIcons.refreshCw, 'Balik', _flip),
      ],
    );
  }
}
