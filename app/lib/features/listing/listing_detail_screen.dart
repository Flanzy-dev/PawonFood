import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/mock/mock_data.dart';
import '../../core/motion/pressable.dart';
import '../../core/models/listing.dart';
import '../../core/services/formatters.dart';
import '../../core/services/geo.dart';
import '../../core/services/negotiation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/info_blocks.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/listing_photo.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';
import '../chat/offer_sheet.dart';

/// B8 Detail makanan: everything needed to decide on one screen, then offer or take.
class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  var _busy = false;

  /// One navigation at a time: a double tap on "Ambil" or a quick offer used to claim twice and open two chats.
  void _open(String path) {
    _busy = true;
    context.push(path).whenComplete(() => _busy = false);
  }

  void _chat(Listing l) {
    if (_busy) return;
    _open('/chat/${ref.read(chatProvider.notifier).openForListing(l.id)}');
  }

  void _claim(Listing l) {
    if (_busy) return;
    _open('/chat/${ref.read(chatProvider.notifier).claim(l.id)}');
  }

  void _offer(Listing l, int amount, {int portions = 1, String message = ''}) {
    if (_busy) return;
    final chat = ref.read(chatProvider.notifier);
    final id = chat.openForListing(l.id);
    final error = chat.sendOffer(id, amount, portions: portions, message: message);
    if (error != null) {
      showAppSnack(context, error);
      return;
    }
    _open('/chat/$id');
  }

  Future<void> _customOffer(Listing l) async {
    final draft = await showOfferSheet(context, listing: l);
    if (draft != null && mounted) _offer(l, draft.amount, portions: draft.portions, message: draft.message);
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(listingByIdProvider(widget.listingId));
    if (l == null) {
      return const NotFoundScaffold(title: 'Makanan tidak ditemukan', fallback: '/', actionLabel: 'Ke Beranda');
    }
    final here = ref.watch(locationProvider).position;
    final now = ref.watch(clockProvider)();
    final distance = distanceMeters(here, l.position);
    final conv = ref.watch(chatProvider.select((all) => all.where((c) => c.listingId == l.id && c.receiverId == meId && (c.pickup?.open ?? false)).firstOrNull));
    final catParts = l.category.label.split(' ');
    final canOffer = l.negotiable && !l.isFree && !l.isOwn && !l.isSoldOut && !l.isExpired(now);
    final quick = quickOffers(l.price);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 272,
                    child: Stack(
                      children: [
                        Positioned.fill(child: Semantics(image: true, label: 'Foto ${l.name}', child: ListingPhoto(l, radius: 0))),
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 120,
                          child: DecoratedBox(
                            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x73111A15), Color(0x00111A15)])),
                          ),
                        ),
                        Positioned(
                          top: top + 8,
                          left: 16,
                          child: RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', shadow: true, onTap: () => context.canPop() ? context.pop() : context.go('/')),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 14,
                          right: 16,
                          // Wrap: at large text or 360 dp the two badges go on two lines instead of overflowing.
                          child: Wrap(spacing: 8, runSpacing: 6, children: [
                            StockBadge(l.portionsLeft, height: 32, size: 14),
                            const Pill('Foto asli, dicek AI', fill: AppColors.surface, icon: LucideIcons.shieldCheck, height: 32, size: 14, weight: 700, hPad: 14),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name, style: AppTypography.display(27, height: 33)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            PersonAvatar(l.provider, size: 56),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.provider.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(18, weight: 700, height: 24)),
                                  const SizedBox(height: 4),
                                  Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                    TierTag(l.provider.tier),
                                    if (l.provider.rating > 0)
                                      Row(mainAxisSize: MainAxisSize.min, children: [
                                        const Icon(Icons.star_rounded, size: 18, color: AppColors.accent),
                                        const SizedBox(width: 4),
                                        Text(formatRating(l.provider.rating), style: AppTypography.text(14, weight: 600)),
                                      ]),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        IntrinsicHeight(
                          child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: StatTile(label: 'Jarak', value: formatDistance(distance), caption: 'area ${areaOf(l.position)}')),
                            const SizedBox(width: 8),
                            Expanded(child: StatTile(label: 'Ambil sebelum', value: formatTime(l.pickupBy), caption: dayCaption(l.pickupBy, now))),
                            const SizedBox(width: 8),
                            Expanded(child: StatTile(label: 'Kategori', value: catParts.first, caption: catParts.skip(1).join(' '))),
                          ],
                        ),
                        ),
                        const SizedBox(height: 12),
                        PriceBox(price: l.price, originalPrice: l.originalPrice, negotiable: l.negotiable),
                        if (canOffer) ...[
                          const SizedBox(height: 16),
                          Text('Tawar cepat', style: AppTypography.titleM),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final amount in quick) ...[
                                Expanded(child: _OfferChip(label: formatRupiah(amount), onTap: () => _offer(l, amount))),
                                const SizedBox(width: 8),
                              ],
                              Expanded(child: _OfferChip(label: 'Tulis sendiri', onTap: () => _customOffer(l))),
                            ],
                          ),
                        ],
                        if (l.description != null) ...[
                          const SizedBox(height: 20),
                          Text('Deskripsi', style: AppTypography.display(16, weight: 700, height: 22)),
                          const SizedBox(height: 6),
                          Text(l.description!, style: AppTypography.text(14, height: 21, color: AppColors.inkMuted)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          StickyBottomBar(child: _bottomActions(l, conv != null, now)),
        ],
      ),
    );
  }

  Widget _bottomActions(Listing l, bool hasPickup, DateTime now) {
    if (l.isOwn) return AppButton(label: 'Lihat pesan', onPressed: () => context.go('/messages'));
    if (l.isSoldOut) return const AppButton(label: 'Habis', onPressed: null);
    // Reached by a link or from an old chat: the pickup window is over, so there is nothing to claim.
    if (!hasPickup && l.isExpired(now)) return const AppButton(label: 'Waktu ambil sudah lewat', onPressed: null);
    if (hasPickup) {
      return ActionPair(secondaryLabel: 'Chat', secondaryIcon: LucideIcons.messageSquare, onSecondary: () => _chat(l), primaryLabel: 'Lihat reservasi', onPrimary: () => _chat(l));
    }
    return ActionPair(
      secondaryLabel: 'Chat',
      secondaryIcon: LucideIcons.messageSquare,
      onSecondary: () => _chat(l),
      primaryLabel: l.isFree ? 'Ambil · Gratis' : 'Ambil · ${formatRupiah(l.price)}',
      onPrimary: () => _claim(l),
    );
  }
}

class _OfferChip extends StatelessWidget {
  const _OfferChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.95,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Container(height: 54, alignment: Alignment.center, child: Text(label, style: AppTypography.text(15, weight: 700)))),
        ),
      );
}
