import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/listings_repository.dart';
import '../../core/data/pickup_points_repository.dart';
import '../../core/data/providers.dart';
import '../../core/mock/mock_data.dart';
import '../../core/motion/pressable.dart';
import '../../core/models/conversation.dart';
import '../../core/models/enums.dart';
import '../../core/models/listing.dart';
import '../../core/services/formatters.dart';
import '../../core/services/fyp.dart';
import '../../core/services/geo.dart';
import '../../core/services/negotiation.dart';
import '../../core/services/recipe_matcher.dart';
import '../../core/services/validators.dart';
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
import '../share/pickup_point_sheet.dart';
import 'handover_choice.dart';
import 'recipe_sheet.dart';

/// B8 Detail makanan: everything needed to decide on one screen, then offer or take.
class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  var _busy = false;

  /// Staying on the detail for 3 s counts as a real look ("view") for the FYP recommender; a quick bounce does not.
  Timer? _viewTimer;

  @override
  void initState() {
    super.initState();
    _viewTimer = Timer(fypViewAfter, () {
      final l = ref.read(listingByIdProvider(widget.listingId));
      if (l != null) ref.read(fypEventsProvider)(l, FypEvent.view);
    });
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    super.dispose();
  }

  /// One navigation at a time: a double tap on "Ambil" or a quick offer used to claim twice and open two chats.
  void _open(String path) {
    _busy = true;
    context.push(path).whenComplete(() => _busy = false);
  }

  void _chat(Listing l) {
    if (_busy) return;
    _open('/chat/${ref.read(chatProvider.notifier).openForListing(l.id)}');
  }

  /// "Cara ambil": picked here, before "Ambil" or an offer, so the button shows the full total and the provider knows
  /// about the delivery before accepting. A delivery goes to the primary saved point unless the receiver changes it.
  var _wantsDelivery = false;
  late PickupPoint _address = ref.read(pickupPointsProvider.notifier).primary;

  /// The delivery to send along: null for "Ambil sendiri", or when this address can not be delivered to. Delivery-only
  /// food always asks for it.
  Delivery? _deliveryFor(Listing l) =>
      (_wantsDelivery || !l.allowsPickup) && Validators.delivery(l, _address.position) == null ? deliveryTo(l, _address) : null;

  /// The receiver can take the food some way: pickup is allowed, or the address can be delivered to.
  bool _reachable(Listing l) => l.allowsPickup || _deliveryFor(l) != null;

  Future<void> _changeAddress() async {
    final picked = await showPickupPointSheet(context, current: _address, title: 'Ubah alamat antar');
    if (picked != null && mounted) {
      setState(() {
        _address = picked;
        _wantsDelivery = true;
      });
    }
  }

  void _claim(Listing l) {
    if (_busy) return;
    _open('/chat/${ref.read(chatProvider.notifier).claim(l.id, delivery: _deliveryFor(l))}');
  }

  void _offer(Listing l, int amount, {int portions = 1, String message = '', Delivery? delivery}) {
    if (_busy) return;
    final chat = ref.read(chatProvider.notifier);
    final id = chat.openForListing(l.id);
    final error = chat.sendOffer(id, amount, portions: portions, message: message, delivery: delivery);
    if (error != null) {
      showAppSnack(context, error);
      return;
    }
    _open('/chat/$id');
  }

  Future<void> _customOffer(Listing l) async {
    final draft = await showOfferSheet(context, listing: l, address: _address, delivery: _deliveryFor(l) != null);
    if (draft != null && mounted) _offer(l, draft.amount, portions: draft.portions, message: draft.message, delivery: draft.delivery);
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
    final canOffer = l.negotiable && !l.isFree && !l.isOwn && !l.isSoldOut && !l.isExpired(now) && _reachable(l);
    // Once a reservation exists the choice is fixed: the chat shows how the food comes.
    final canChooseHandover = l.canDeliver && !l.isOwn && !l.isSoldOut && !l.isExpired(now) && conv == null;
    final quick = quickOffers(l.price);
    final top = MediaQuery.paddingOf(context).top;
    // Recipe ideas are for buyers. The recipe the seller attached counts as verified; without one the best match from the
    // local library is still offered, labelled as not verified.
    final attached = l.recipe;
    final recipe = l.category != FoodCategory.bahanMentah || l.isOwn
        ? null
        : (attached ?? suggestRecipes('${l.name} ${l.description ?? ''}', ref.watch(recipesProvider), limit: 1).firstOrNull?.recipe);

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
                            // Only a photo the AI approved: one waiting for manual review has not been "checked" yet.
                            if (l.aiStatus == AiStatus.approved)
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
                            Expanded(child: StatTile(label: l.allowsPickup ? 'Ambil sebelum' : 'Antar sebelum', value: formatTime(l.pickupBy), caption: dayCaption(l.pickupBy, now))),
                            const SizedBox(width: 8),
                            Expanded(child: StatTile(label: 'Kategori', value: catParts.first, caption: catParts.skip(1).join(' '))),
                          ],
                        ),
                        ),
                        if (l.healthTags.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text('Pilihan sehat', style: AppTypography.display(16, weight: 700, height: 22)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 6, children: [for (final t in HealthTag.values) if (l.healthTags.contains(t)) InfoTag(t.label, height: 28, size: 13)]),
                          const SizedBox(height: 6),
                          Text('Diisi oleh pemberi, dibantu AI.', style: AppTypography.caption),
                        ],
                        const SizedBox(height: 12),
                        PriceBox(price: l.price, originalPrice: l.originalPrice, negotiable: l.negotiable),
                        if (canChooseHandover) ...[
                          const SizedBox(height: 16),
                          HandoverChoice(
                            listing: l,
                            address: _address,
                            delivery: _wantsDelivery,
                            onChanged: (v) => setState(() => _wantsDelivery = v),
                            onChangeAddress: _changeAddress,
                          ),
                        ],
                        if (canOffer) ...[
                          const SizedBox(height: 16),
                          Text('Tawar cepat', style: AppTypography.titleM),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final amount in quick) ...[
                                Expanded(child: _OfferChip(label: formatRupiah(amount), onTap: () => _offer(l, amount, delivery: _deliveryFor(l)))),
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
                        if (recipe != null) ...[
                          const SizedBox(height: 20),
                          Text('Ide resep', style: AppTypography.display(16, weight: 700, height: 22)),
                          const SizedBox(height: 8),
                          RecipeCard(recipe: recipe, verified: attached != null),
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
    // The total follows "Cara ambil": the food plus the delivery fee when "Minta diantar" is picked.
    final total = l.price + (_deliveryFor(l)?.fee ?? 0);
    // Delivery-only food to an address over 1 km: nothing to take until the receiver picks a nearer address.
    if (!_reachable(l)) {
      return ActionPair(secondaryLabel: 'Chat', secondaryIcon: LucideIcons.messageSquare, onSecondary: () => _chat(l), primaryLabel: 'Alamatmu di luar jangkauan antar', onPrimary: null);
    }
    return ActionPair(
      secondaryLabel: 'Chat',
      secondaryIcon: LucideIcons.messageSquare,
      onSecondary: () => _chat(l),
      primaryLabel: total == 0 ? 'Ambil · Gratis' : 'Ambil · ${formatRupiah(total)}',
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
