import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/page_dots.dart';

/// The hero photos that slide automatically on A1, with their screen-reader labels. (The Figma illustrations are
/// ready in `assets/images/brand/welcome_1-3.jpg` for when the artwork replaces the food photos; they need the
/// full-cream layout, not this full-bleed photo one.)
const _heroSlides = [
  ('assets/images/brand/hero.jpg', 'Nasi campur dengan lauk'),
  ('assets/images/food/ayam2.jpg', 'Ayam goreng lalapan'),
  ('assets/images/food/lodeh2.jpg', 'Sayur lodeh'),
];

/// Time each hero photo stays before the next one slides in.
const _heroInterval = Duration(seconds: 4);

/// A1 Welcome: hero food photos, wordmark and the two entry actions.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Start far from zero so the carousel can also be swiped backwards while looping forever.
  static const _startPage = 3000;

  final _controller = PageController(initialPage: _startPage);
  Timer? _timer;
  int _index = 0;
  bool _timerStarted = false;
  bool _dragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No auto-advance when the OS asks for reduced motion (this also keeps widget tests free of pending timers).
    if (!_timerStarted && !Motion.reduced(context)) {
      _timerStarted = true;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_heroInterval, (_) {
      // Never slide under a finger, or while Daftar/Masuk covers this screen (its ticker is muted then).
      if (_dragging || !(ModalRoute.of(context)?.isCurrent ?? true) || !_controller.hasClients) return;
      _controller.nextPage(duration: Motion.slow, curve: Motion.move);
    });
  }

  void _onPageChanged(int page) {
    setState(() => _index = page % _heroSlides.length);
    // A manual swipe gets the full interval before the next automatic slide.
    if (_timerStarted && !_dragging) _restartTimer();
  }

  bool _onScroll(ScrollNotification n) {
    if (!_timerStarted) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _dragging = true;
      _timer?.cancel();
    } else if (n is ScrollEndNotification && _dragging) {
      _dragging = false;
      _restartTimer();
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, c) => Column(
          children: [
            // The photo fills everything above the sheet and runs 32 dp behind it, so the sheet's rounded corners sit on the
            // photo (as in Figma) at any screen height.
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The photo settles from a slight zoom while the sheet rises: one calm opening move.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: -32,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: Motion.reduced(context) ? 1 : 1.08, end: 1),
                      duration: Motion.of(context, const Duration(milliseconds: 1400)),
                      curve: Curves.easeOutCubic,
                      builder: (_, s, child) => Transform.scale(scale: s, child: child),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: PageView.builder(
                          controller: _controller,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (_, i) {
                            final (asset, label) = _heroSlides[i % _heroSlides.length];
                            return Image.asset(asset, fit: BoxFit.cover, semanticLabel: label);
                          },
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x73111A15), Color(0x00111A15)])),
                    ),
                  ),
                ],
              ),
            ),
            // At large text sizes the sheet grows: it scrolls instead of overflowing, and the photo keeps at least 160 dp.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: (c.maxHeight - 160).clamp(0, double.infinity)),
              child: SingleChildScrollView(
                child: FadeSlideIn(
              offset: 40,
              duration: const Duration(milliseconds: 600),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
                decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(alignment: Alignment.center, child: PageDots(count: _heroSlides.length, index: _index, label: 'Gambar ${_index + 1} dari ${_heroSlides.length}')),
                    const SizedBox(height: 10),
                    const FadeSlideIn(delay: Duration(milliseconds: 200), child: Wordmark(width: 190)),
                    const SizedBox(height: 17),
                    FadeSlideIn(delay: const Duration(milliseconds: 260), child: Text('Masak kebanyakan? Bagikan, jangan buang.', style: AppTypography.display(30, height: 36))),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 320),
                      child: Text('Penyelamatan makanan dari dapur ke komunitas.', style: AppTypography.text(15, weight: 500, color: AppColors.inkMuted)),
                    ),
                    const SizedBox(height: 28),
                    AppButton(label: 'Daftar', onPressed: () => context.push('/register')),
                    const SizedBox(height: 12),
                    AppButton(label: 'Sudah punya akun? Masuk', variant: AppButtonVariant.outline, onPressed: () => context.push('/login')),
                    const SizedBox(height: 24),
                    Text(
                      'Dengan mendaftar, kamu menyetujui Syarat & Ketentuan dan Kebijakan Privasi PawonFood.',
                      textAlign: TextAlign.center,
                      style: AppTypography.text(12, height: 17, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
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
