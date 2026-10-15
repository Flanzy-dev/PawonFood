import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/onboarding_repository.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/page_dots.dart';

/// The three intro slides: illustration, its screen-reader label, title and body (Figma A0a-A0c).
const _slides = [
  ('assets/images/brand/welcome_1.jpg', 'Tangan memberi bungkusan makanan', 'Bagikan makanan berlebih', 'Foto makananmu, pilih gratis atau jual murah, dan tetangga sekitar langsung bisa melihatnya.'),
  ('assets/images/brand/welcome_2.jpg', 'Dua orang mengobrol sambil serah terima makanan', 'Temukan makanan di dekatmu', 'Lihat di peta, tawar lewat chat, dan atur waktu ambil.'),
  ('assets/images/brand/welcome_3.jpg', 'Serah terima makanan dengan senyum', 'Ambil, pindai, dapat poin', 'Pindai QR saat mengambil. Setiap porsi yang terselamatkan menambah poinmu.'),
];

/// A0a-A0c Onboarding: shown once, on the first launch on a device, before A1 Welcome. Lewati or Mulai marks it seen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _last => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) return _finish();
    if (Motion.reduced(context)) {
      _controller.jumpToPage(_index + 1);
    } else {
      _controller.nextPage(duration: Motion.slow, curve: Motion.move);
    }
  }

  void _finish() {
    ref.read(onboardingSeenProvider.notifier).finish();
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: _last ? 0 : 1,
                  duration: Motion.of(context, Motion.base),
                  child: IgnorePointer(
                    ignoring: _last,
                    child: ExcludeSemantics(
                      excluding: _last,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Semantics(
                          button: true,
                          label: 'Lewati perkenalan',
                          excludeSemantics: true,
                          onTap: _finish,
                          child: InkWell(
                            onTap: _finish,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Center(widthFactor: 1, child: Text('Lewati', style: AppTypography.text(15, weight: 600, color: AppColors.primary))),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FadeSlideIn(
                  offset: 16,
                  duration: const Duration(milliseconds: 500),
                  child: LayoutBuilder(builder: (context, c) {
                    // The square illustration is 338 dp on a normal phone and gives way to the text on short screens or
                    // at large text sizes, down to 160 dp; the text then scrolls.
                    final textRoom = 190 * MediaQuery.textScalerOf(context).scale(1);
                    final side = math.min(338.0, math.min(c.maxWidth - 64, c.maxHeight - 16 - 60 - textRoom)).clamp(160.0, 338.0);
                    return Stack(
                      children: [
                        PageView.builder(
                          controller: _controller,
                          itemCount: _slides.length,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemBuilder: (_, i) => _Slide(slide: _slides[i], side: side),
                        ),
                        // The dots stay put while the slides move under them.
                        Positioned(
                          top: 16 + side + 28,
                          left: 0,
                          right: 0,
                          child: Center(child: PageDots(count: _slides.length, index: _index, label: 'Halaman ${_index + 1} dari ${_slides.length}')),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: AppButton(label: _last ? 'Mulai' : 'Lanjut', onPressed: _next),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide, required this.side});

  final (String, String, String, String) slide;
  final double side;

  @override
  Widget build(BuildContext context) {
    final (asset, alt, title, body) = slide;
    return Column(
      children: [
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(asset, width: side, height: side, fit: BoxFit.cover, semanticLabel: alt),
        ),
        // 28 above the dots, 8 for the dots, 24 below them.
        const SizedBox(height: 60),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(title, style: AppTypography.display(28, height: 34))),
                  const SizedBox(height: 10),
                  Text(body, style: AppTypography.text(15, height: 22, color: AppColors.inkMuted)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
