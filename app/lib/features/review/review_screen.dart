import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/models/conversation.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/listing_photo.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../ads/ad_screen.dart';

/// B11 Ulasan: opens right after the QR scan, while the receiver is still at the pickup point. A good rating earns
/// the provider bonus points. After "Kirim ulasan" the post-review ad shows (at most once a day).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  static const _tags = ['Masih hangat', 'Porsi pas', 'Sesuai foto', 'Penyedia ramah'];
  final _comment = TextEditingController();
  final _selected = <String>{};
  var _rating = 0;
  static const _ratingWords = ['Kurang', 'Biasa', 'Cukup', 'Bagus', 'Mantap'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  var _sent = false;

  void _submit(Conversation conv) {
    if (_sent) return; // a second tap while the next screen opens must not send the review twice
    _sent = true;
    ref.read(chatProvider.notifier).submitReview(conv.id, Review(pickupId: conv.pickup?.id ?? conv.id, rating: _rating, tags: _selected.toList(), comment: _comment.text.trim()));
    if (takeAdSlot(ref)) {
      context.go('/ad');
    } else {
      showAppSnack(context, 'Terima kasih! Ulasanmu terkirim.');
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final conv = ref.watch(conversationProvider(widget.conversationId));
    final listing = conv == null ? null : ref.watch(listingByIdProvider(conv.listingId));
    if (conv == null || listing == null) return const NotFoundScaffold(title: 'Pesanan tidak ditemukan');
    final now = ref.watch(clockProvider)();
    final amount = conv.offer?.total ?? listing.price;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', onTap: () => context.canPop() ? context.pop() : context.go('/')),
                Expanded(child: Text('Beri ulasan', textAlign: TextAlign.center, style: AppTypography.text(17, weight: 700))),
                const SizedBox(width: 44),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      ListingPhoto(listing, width: 68, height: 68, radius: 14),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(listing.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(16, weight: 700, height: 21)),
                          Text('${listing.provider.name} · ${amount == 0 ? 'Gratis' : formatRupiah(amount)}', style: AppTypography.text(14, color: AppColors.inkMuted)),
                          Row(children: [
                            const Icon(LucideIcons.check, size: 15, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Pengambilan berhasil · ${formatTime(conv.pickup?.pickedUpAt ?? now)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.text(13, weight: 600, color: AppColors.primary))),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  Text('Bagaimana makanannya?', style: AppTypography.display(24, height: 30)),
                  const SizedBox(height: 12),
                  Row(children: [
                    for (var i = 1; i <= 5; i++)
                      Semantics(
                        button: true,
                        selected: i == _rating,
                        label: '$i bintang',
                        child: InkResponse(
                          onTap: () => setState(() => _rating = i),
                          radius: 30,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            // Stars up to the tapped one fill in turn and pop, so the rating reads as a gesture.
                            child: AnimatedScale(
                              scale: i <= _rating ? 1 : 0.92,
                              duration: Motion.of(context, Motion.base + Motion.stagger * (i - 1)),
                              curve: Motion.pop,
                              child: TweenAnimationBuilder<Color?>(
                                tween: ColorTween(end: i <= _rating ? AppColors.accent : AppColors.inkMuted),
                                duration: Motion.of(context, Motion.fast + Motion.stagger * (i - 1)),
                                // Filled vs outline, so the rating never depends on colour alone.
                                builder: (_, c, _) => Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 50, color: c),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  // The rating in words, next to the stars.
                  AnimatedSize(
                    // 1 ms instead of zero under reduced motion: a zero-length AnimatedSize re-dirties itself inside layout.
                    duration: Motion.reduced(context) ? const Duration(milliseconds: 1) : Motion.fast,
                    alignment: Alignment.topLeft,
                    child: _rating == 0
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('${_ratingWords[_rating - 1]} · $_rating/5', style: AppTypography.text(15, weight: 600, color: AppColors.inkMuted)),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Text('Apa yang bagus?', style: AppTypography.display(16, weight: 700)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in _tags)
                      AppChip(label: t, selected: _selected.contains(t), onTap: () => setState(() => _selected.contains(t) ? _selected.remove(t) : _selected.add(t))),
                  ]),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _comment,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 300,
                    style: AppTypography.text(16),
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: 'Tulis ulasan singkat (opsional)',
                      hintStyle: AppTypography.text(16, color: AppColors.inkMuted),
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.all(16),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderStrong)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Kamu mendapat poin setelah menilai. Ulasan buruk berulang bisa membuat penyedia di-suspend, lalu diblokir jika berlanjut.', style: AppTypography.text(13, height: 19, color: AppColors.inkMuted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AppButton(label: 'Kirim ulasan', onPressed: _rating == 0 ? null : () => _submit(conv)),
            ),
          ],
        ),
      ),
    );
  }
}
