import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/mock/mock_data.dart';
import '../../core/models/listing.dart';
import '../../core/services/formatters.dart';
import '../../core/services/geo.dart';
import '../../core/services/negotiation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/form_controls.dart';
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
  var _consent = false;
  var _consentError = false;

  bool _requireConsent() {
    if (_consent) return true;
    setState(() => _consentError = true);
    return false;
  }

  void _chat(Listing l) => context.push('/chat/${ref.read(chatProvider.notifier).openForListing(l.id)}');

  void _claim(Listing l) {
    if (!_requireConsent()) return;
    context.push('/chat/${ref.read(chatProvider.notifier).claim(l.id)}');
  }

  void _offer(Listing l, int amount) {
    if (!_requireConsent()) return;
    final chat = ref.read(chatProvider.notifier);
    final id = chat.openForListing(l.id);
    final error = chat.sendOffer(id, amount);
    if (error != null) {
      showAppSnack(context, error);
      return;
    }
    context.push('/chat/$id');
  }

  Future<void> _customOffer(Listing l) async {
    final amount = await showOfferSheet(context, price: l.price);
    if (amount != null && mounted) _offer(l, amount);
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(listingByIdProvider(widget.listingId));
    if (l == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Listing tidak ditemukan')));
    }
    final here = ref.watch(locationProvider).position;
    final now = ref.watch(clockProvider)();
    final distance = distanceMeters(here, l.position);
    final conv = ref.watch(chatProvider.select((all) => all.where((c) => c.listingId == l.id && c.receiverId == meId && c.pickup != null).firstOrNull));
    final catParts = l.category.label.split(' ');
    final canOffer = l.negotiable && !l.isFree && !l.isOwn && !l.isSoldOut;
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
                        Positioned.fill(child: ListingPhoto(l, radius: 0)),
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
                          child: Row(children: [
                            StockBadge(l.portionsLeft, height: 32, size: 14),
                            const SizedBox(width: 8),
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
                                  Row(children: [
                                    TierTag(l.provider.tier),
                                    if (l.provider.rating > 0) ...[
                                      const SizedBox(width: 10),
                                      const Icon(Icons.star_rounded, size: 18, color: AppColors.accent),
                                      const SizedBox(width: 4),
                                      Text(formatRating(l.provider.rating), style: AppTypography.text(14, weight: 600)),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: StatTile(label: 'Jarak', value: formatDistance(distance), caption: 'jalan kaki')),
                            const SizedBox(width: 8),
                            Expanded(child: StatTile(label: 'Ambil sebelum', value: formatTime(l.pickupBy), caption: dayCaption(l.pickupBy, now))),
                            const SizedBox(width: 8),
                            Expanded(child: StatTile(label: 'Kategori', value: catParts.first, caption: catParts.skip(1).join(' '))),
                          ],
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
                        if (!l.isOwn && !l.isSoldOut) ...[
                          const SizedBox(height: 12),
                          AppCheckbox(
                            value: _consent,
                            textSize: 13,
                            label: 'Saya telah memeriksa kondisi makanan dan membebaskan PawonFood dari tuntutan kesehatan.',
                            onChanged: (v) => setState(() {
                              _consent = v;
                              if (v) _consentError = false;
                            }),
                          ),
                          if (_consentError)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(children: [
                                const Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.error),
                                const SizedBox(width: 6),
                                Expanded(child: Text('Centang persetujuan dulu untuk melanjutkan.', style: AppTypography.text(13, weight: 600, color: AppColors.error))),
                              ]),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          StickyBottomBar(child: _bottomActions(l, conv != null)),
        ],
      ),
    );
  }

  Widget _bottomActions(Listing l, bool hasPickup) {
    if (l.isOwn) return AppButton(label: 'Lihat pesan', onPressed: () => context.go('/messages'));
    if (l.isSoldOut) return const AppButton(label: 'Habis', onPressed: null);
    if (hasPickup) {
      return ActionPair(secondaryLabel: 'Chat', secondaryIcon: LucideIcons.messageSquare, onSecondary: () => _chat(l), primaryLabel: 'Lihat kode ambil', onPrimary: () => _chat(l));
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
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Container(height: 54, alignment: Alignment.center, child: Text(label, style: AppTypography.text(15, weight: 700)))),
      );
}
