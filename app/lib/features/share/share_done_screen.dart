import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/navigation_widgets.dart';

/// Step 3 of 3 (C16): the listing is live. Only the success message, the points summary and one "Kembali" button.
class ShareDoneScreen extends StatelessWidget {
  const ShareDoneScreen({super.key, required this.listingId});

  /// The published listing (kept in the route; this screen no longer shows its card).
  final String listingId;

  @override
  Widget build(BuildContext context) => Scaffold(
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
                          Container(width: 104, height: 104, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(LucideIcons.check, size: 56, color: AppColors.background)),
                          const SizedBox(height: 24),
                          Text('Makananmu sudah tayang!', textAlign: TextAlign.center, style: AppTypography.display(27, height: 33)),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text('Penerima di sekitar Pogung bisa melihatnya sekarang dan mengajukan tawaran.', textAlign: TextAlign.center, style: AppTypography.bodyMuted),
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
      );
}
