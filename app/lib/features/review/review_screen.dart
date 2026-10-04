import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/models/conversation.dart';
import '../../core/services/formatters.dart';
import '../../core/services/points.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/listing_photo.dart';
import '../../core/widgets/navigation_widgets.dart';

/// B11 Ulasan: shown after "Sudah saya ambil". A good rating earns the provider bonus points.
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

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit(Conversation conv) {
    ref.read(chatProvider.notifier).submitReview(conv.id, Review(pickupId: conv.pickup?.id ?? conv.id, rating: _rating, tags: _selected.toList(), comment: _comment.text.trim()));
    showAppSnack(context, 'Terima kasih! Ulasanmu terkirim.');
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final conv = ref.watch(conversationProvider(widget.conversationId));
    final listing = conv == null ? null : ref.watch(listingByIdProvider(conv.listingId));
    if (conv == null || listing == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Pesanan tidak ditemukan')));
    final now = ref.watch(clockProvider)();
    final amount = conv.offer?.amount ?? listing.price;
    final points = pickupPoints(portions: conv.offer?.portions ?? 1, isFree: amount == 0, rating: _rating == 0 ? null : _rating);

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
                          Text('Diambil hari ini · ${formatTime(conv.pickup?.pickedUpAt ?? now)}', style: AppTypography.text(13, color: AppColors.inkMuted)),
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
                            child: Icon(Icons.star_rounded, size: 50, color: i <= _rating ? AppColors.accent : AppColors.border),
                          ),
                        ),
                      ),
                  ]),
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
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Penyedia mendapat $points poin setelah kamu menilai. Ulasan buruk berulang bisa membuat penyedia diblokir.', style: AppTypography.text(13, height: 19, color: AppColors.inkMuted)),
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
