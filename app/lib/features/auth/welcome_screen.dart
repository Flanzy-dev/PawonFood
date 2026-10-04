import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/brand.dart';

/// A1 Welcome: hero food photo, wordmark and the two entry actions.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: Image.asset('assets/images/brand/hero.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter, semanticLabel: 'Nasi campur dengan lauk')),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x73111A15), Color(0x00111A15)])),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 26, 16, 16 + bottom),
                decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wordmark(width: 190),
                    const SizedBox(height: 16),
                    Text('Masak kebanyakan? Bagikan, jangan buang.', style: AppTypography.display(30, height: 36)),
                    const SizedBox(height: 10),
                    Text('Dari dapur ke dapur · Yogyakarta', style: AppTypography.text(15, weight: 500, color: AppColors.inkMuted)),
                    const SizedBox(height: 24),
                    AppButton(label: 'Daftar', onPressed: () => context.push('/register')),
                    const SizedBox(height: 12),
                    AppButton(label: 'Sudah punya akun? Masuk', variant: AppButtonVariant.outline, onPressed: () => context.push('/login')),
                    const SizedBox(height: 16),
                    Text(
                      'Dengan mendaftar, kamu menyetujui Syarat & Ketentuan dan Kebijakan Privasi PawonFood.',
                      textAlign: TextAlign.center,
                      style: AppTypography.text(12, height: 17, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
