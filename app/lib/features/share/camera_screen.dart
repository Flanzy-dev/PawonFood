import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/food_validator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';
import 'share_state.dart';

enum _Phase { starting, ready, capturing, denied, unavailable }

/// Step 1 of 3 (C12–C14): a plain camera, never a gallery picker. The AI check runs in the background once the photo
/// is taken (see [ShareCaptureNotifier]) and fills in the form; there is no scan effect here.
/// Long-press the title to choose the simulated AI result (demo mode, simulated validator only).
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  late final AppCamera _camera = ref.read(cameraFactoryProvider)();
  late final bool _cloud = ref.read(cloudValidatorProvider);
  var _phase = _Phase.starting;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_camera.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _phase = _Phase.starting);
    _apply(await _camera.start());
  }

  void _apply(CameraStatus status) {
    if (!mounted) return;
    setState(() => _phase = switch (status) {
          CameraStatus.ready => _Phase.ready,
          CameraStatus.denied => _Phase.denied,
          CameraStatus.unavailable => _Phase.unavailable,
        });
  }

  /// Takes the photo, starts the AI check without waiting for it and opens the form right away.
  Future<void> _capture() async {
    if (_phase != _Phase.ready) return;
    setState(() => _phase = _Phase.capturing);
    final String path;
    try {
      path = await _camera.capture();
    } on Object {
      if (!mounted) return;
      setState(() => _phase = _Phase.ready);
      showAppSnack(context, 'Foto gagal diambil. Coba lagi.');
      return;
    }
    if (!mounted) return;
    unawaited(ref.read(shareCaptureProvider.notifier).start(path));
    await context.push('/share/form');
    if (mounted) setState(() => _phase = _Phase.ready);
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
    showAppSheet<void>(
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
    showAppSheet<void>(
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
                      onLongPress: _cloud ? null : _chooseDemoMode,
                      behavior: HitTestBehavior.opaque,
                      child: Semantics(
                        hint: _cloud ? null : 'Tekan lama untuk mode demo AI',
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
                const ColoredBox(color: AppColors.scrimDim),
                const Positioned(left: 16, bottom: 16, child: Pill('Pratinjau kamera', fill: AppColors.scrimLabel, color: AppColors.surfaceSand, height: 32, size: 14, weight: 500, hPad: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Arahkan kamera ke makanan', style: AppTypography.display(22, height: 27, color: AppColors.background)),
              const SizedBox(height: 4),
              Text('Pastikan makanan terlihat jelas dan cahaya cukup.', style: AppTypography.text(14, color: AppColors.cameraText)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _controls(),
      ],
    );
  }

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
                  child: busy && !Motion.reduced(context) ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary)) : const PawonLogo(size: 36, color: AppColors.primary),
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
