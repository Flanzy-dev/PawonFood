import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/listings_repository.dart';
import '../../core/motion/motion_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/navigation_widgets.dart';

/// Step 3 of 3 (C16): the listing is live. Only the success message, the points summary and one "Kembali" button.
class ShareDoneScreen extends ConsumerWidget {
  const ShareDoneScreen({super.key, required this.listingId});

  /// The published listing (kept in the route; this screen no longer shows its card).
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
        // Back from "tayang" must not return to the camera with the old capture; it goes home like "Kembali".
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/');
        },
        child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                const StepProgress(current: 3),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CheckBurst(size: 104, flood: true),
                          const SizedBox(height: 24),
                          Text('Makananmu sudah tayang!', textAlign: TextAlign.center, style: AppTypography.display(27, height: 33)),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text('Penerima di sekitar ${ref.watch(locationProvider).name.split(',').first} bisa melihatnya sekarang dan mengajukan tawaran.', textAlign: TextAlign.center, style: AppTypography.bodyMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Kamu dapat poin saat makanan diambil dan dinilai baik. Makanan gratis memberi poin lebih banyak.', textAlign: TextAlign.center, style: AppTypography.text(14, height: 20, color: AppColors.inkMuted)),
                ),
                const SizedBox(height: 16),
                AppButton(label: 'Kembali', onPressed: () => context.go('/')),
              ],
            ),
          ),
        ),
        ),
      );
}
