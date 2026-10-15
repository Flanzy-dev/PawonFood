import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/providers.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/layout_widgets.dart';

/// Mock sponsor (eco-friendly FMCG only, PRD Ads). Fictional brand for the demo.
abstract final class _Sponsor {
  static const brand = 'Wadahku';
  static const title = 'Bawa wadah sendiri, kurangi plastik';
  static const line = 'Wadah kaca tahan panas untuk bawa pulang makanan.';
  static const footer = 'Iklan membantu PawonFood tetap gratis untuk penerima.';
}

/// When the post-review ad last showed: at most one per receiver per day (PRD Ads, Proposed).
final lastAdShownProvider = StateProvider<DateTime?>((ref) => null);

/// True when an ad may show now; marks it as shown.
bool takeAdSlot(WidgetRef ref) {
  final now = ref.read(clockProvider)();
  final last = ref.read(lastAdShownProvider);
  if (last != null && last.year == now.year && last.month == now.month && last.day == now.day) return false;
  ref.read(lastAdShownProvider.notifier).state = now;
  return true;
}

/// B11b (image) / B11c (video) full-screen ad after "Kirim ulasan" (post-MVP, built for the demo). Both share B11b's
/// layout: full-bleed photo, dark scrim and white sponsor copy at the bottom. The video is simulated with a slowly
/// zooming still and a 15 s progress bar, so there is no video asset or player.
/// Long-press the "Iklan" pill to swap image and video (demo).
class AdScreen extends ConsumerStatefulWidget {
  const AdScreen({super.key, this.video});

  /// Null picks one at random.
  final bool? video;

  @override
  ConsumerState<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends ConsumerState<AdScreen> with SingleTickerProviderStateMixin {
  late bool _video = widget.video ?? ref.read(randomProvider).nextBool();
  late final AnimationController _play = AnimationController(vsync: this, duration: const Duration(seconds: 15))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _close();
    });
  Timer? _tick;
  var _wait = 5;
  var _muted = true;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait = (_wait - 1).clamp(0, 5));
      if (_wait == 0) t.cancel();
    });
    if (_video) _play.forward();
  }

  void _swapFormat() => setState(() {
        _video = !_video;
        _video ? _play.forward(from: 0) : _play.stop();
      });

  @override
  void dispose() {
    _tick?.cancel();
    _play.dispose();
    super.dispose();
  }

  void _close() {
    if (mounted) context.go('/');
  }

  void _learnMore() => showAppSnack(context, 'Halaman ${_Sponsor.brand} segera hadir.');

  @override
  Widget build(BuildContext context) {
    final canClose = _wait == 0;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: canClose,
        onPopInvokedWithResult: (didPop, _) {
          // Back is blocked for the first seconds; say why instead of ignoring it.
          if (!didPop) showAppSnack(context, 'Iklan bisa ditutup dalam $_wait detik.');
        },
        child: Scaffold(
          backgroundColor: AppColors.cameraBg,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Image, slowly zooming when it stands in for a video.
              AnimatedBuilder(
                animation: _play,
                builder: (_, child) => Transform.scale(scale: _video && !Motion.reduced(context) ? 1 + 0.08 * _play.value : 1, child: child),
                child: Image.asset(_video ? 'assets/images/food/lodeh.jpg' : 'assets/images/brand/hero.jpg', fit: BoxFit.cover, excludeFromSemantics: true),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.25, 0.9], colors: [Color(0x00111A15), Color(0xE6111A15)]),
                ),
              ),
              if (_video) ...[
                Positioned(
                  top: top + 6,
                  left: 16,
                  right: 16,
                  child: AnimatedBuilder(
                    animation: _play,
                    builder: (_, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(value: _play.value, minHeight: 4, color: AppColors.background, backgroundColor: AppColors.background.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
                Center(
                  child: Semantics(
                    button: true,
                    label: _play.isAnimating ? 'Jeda' : 'Putar',
                    child: GestureDetector(
                      onTap: () => setState(() => _play.isAnimating ? _play.stop() : _play.forward()),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(color: AppColors.cameraBg.withValues(alpha: 0.55), shape: BoxShape.circle),
                        child: AnimatedSwitcher(
                          duration: Motion.of(context, Motion.fast),
                          child: Icon(_play.isAnimating ? LucideIcons.pause : LucideIcons.play, key: ValueKey(_play.isAnimating), size: 34, color: AppColors.background),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Positioned(
                top: top + 20,
                left: 16,
                right: 16,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(onLongPress: _swapFormat, child: const _GlassPill('Iklan')),
                    if (_video) ...[
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: _play,
                        builder: (_, _) => _GlassPill('0:${(_play.value * 15).floor().toString().padLeft(2, '0')} / 0:15', small: true),
                      ),
                    ],
                  ]),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Semantics(
                      button: canClose,
                      label: canClose ? (_video ? 'Lewati iklan' : 'Tutup iklan') : '${_video ? 'Lewati' : 'Tutup'} dalam $_wait detik',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: canClose ? _close : null,
                        child: AnimatedSwitcher(
                          duration: Motion.of(context, Motion.base),
                          child: _GlassPill(
                            key: ValueKey(canClose),
                            canClose ? (_video ? 'Lewati' : 'Tutup') : '${_video ? 'Lewati' : 'Tutup'} dalam $_wait',
                            icon: canClose ? LucideIcons.x : null,
                          ),
                        ),
                      ),
                    ),
                    if (_video) ...[
                      const SizedBox(height: 10),
                      Semantics(
                        button: true,
                        label: _muted ? 'Nyalakan suara' : 'Matikan suara',
                        child: GestureDetector(
                          onTap: () => setState(() => _muted = !_muted),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: AppColors.cameraBg.withValues(alpha: 0.7), shape: BoxShape.circle),
                            child: Icon(_muted ? LucideIcons.volumeX : LucideIcons.volume2, size: 20, color: AppColors.background),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: bottom + 16,
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  offset: 24,
                  // At large text sizes the sponsor copy can grow tall: cap it and let it scroll instead of overflowing.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                    child: SingleChildScrollView(child: _ImageCopy(onLearn: _learnMore)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill(this.text, {super.key, this.icon, this.small = false});

  final String text;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
        height: small ? 32 : 48,
        padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
        decoration: BoxDecoration(color: AppColors.cameraBg.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(22)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: AppTypography.text(small ? 13 : 14, weight: small ? 500 : 700, color: AppColors.background)),
          if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: 16, color: AppColors.background)],
        ]),
      );
}

class _ImageCopy extends StatelessWidget {
  const _ImageCopy({required this.onLearn});

  final VoidCallback onLearn;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Disponsori oleh ${_Sponsor.brand}', style: AppTypography.text(13, color: AppColors.cameraText)),
          const SizedBox(height: 4),
          Text(_Sponsor.title, style: AppTypography.display(26, height: 32, color: AppColors.background)),
          const SizedBox(height: 6),
          Text(_Sponsor.line, style: AppTypography.text(15, height: 22, color: AppColors.cameraText)),
          const SizedBox(height: 18),
          AppButton(label: 'Pelajari', variant: AppButtonVariant.light, onPressed: onLearn),
          const SizedBox(height: 12),
          Center(child: Text(_Sponsor.footer, style: AppTypography.text(12, color: AppColors.cameraText))),
        ],
      );
}
