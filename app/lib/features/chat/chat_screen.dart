import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/listings_repository.dart';
import '../../core/data/pickup_points_repository.dart';
import '../../core/data/providers.dart';
import '../../core/mock/mock_data.dart';
import '../../core/models/conversation.dart';
import '../../core/models/enums.dart';
import '../../core/models/listing.dart';
import '../../core/models/person.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/motion_widgets.dart';
import '../../core/services/formatters.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/brand_icons.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/listing_summary.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/option_row.dart';
import '../../core/widgets/pills.dart';
import '../listing/handover_choice.dart';
import 'fee_offer_sheet.dart';
import 'offer_sheet.dart';

/// What the "+" menu asks to haggle over.
enum _OfferKind { food, fee }

/// B10 Chat negosiasi: listing card, offer cards, bubbles, the reservation card (B10 / B10i / B10j) and the
/// composer. The other party is simulated.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Messages already there when the chat opened appear at once; only new ones animate in.
  Set<String>? _initial;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      animate && !Motion.reduced(context) ? _scroll.animateTo(end, duration: Motion.slow, curve: Motion.move) : _scroll.jumpTo(end);
    });
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    ref.read(chatProvider.notifier).sendText(widget.conversationId, text);
    _input.clear();
    _toBottom();
  }

  /// "Tawar lagi": the sheet starts from the last offer's pickup or delivery choice, and from the ongkir the provider
  /// countered with (or the one offered last).
  Future<void> _counterOffer(Listing l) async {
    final last = ref.read(conversationProvider(widget.conversationId))?.offer;
    final drop = last?.delivery;
    final address = drop == null ? ref.read(pickupPointsProvider.notifier).primary : pointOf(drop);
    final draft = await showOfferSheet(context, listing: l, address: address, delivery: drop != null, fee: last?.counterFee ?? drop?.fee);
    if (draft == null || !mounted) return;
    final error = ref
        .read(chatProvider.notifier)
        .sendOffer(widget.conversationId, draft.amount, portions: draft.portions, message: draft.message, delivery: draft.delivery, deliveryFee: draft.deliveryFee);
    if (error != null) {
      showAppSnack(context, error);
    } else {
      _toBottom();
    }
  }

  /// "Tawar RpX": offers the provider's counter price (and counter ongkir) with the last offer's portions and pickup or
  /// delivery.
  void _offerCounter(Listing l, Offer last) {
    final error = ref
        .read(chatProvider.notifier)
        .sendOffer(widget.conversationId, last.counter!, portions: last.portions.clamp(1, l.portionsLeft), delivery: last.delivery, deliveryFee: last.counterFee);
    if (error != null) {
      showAppSnack(context, error);
    } else {
      _toBottom();
    }
  }

  /// Where a delivery would go: the last offer's address, else the primary saved point.
  PickupPoint _dropPoint() {
    final drop = ref.read(conversationProvider(widget.conversationId))?.offer?.delivery;
    return drop == null ? ref.read(pickupPointsProvider.notifier).primary : pointOf(drop);
  }

  /// "Tawar ongkir" has nothing to haggle when the provider does not deliver, the fee is already free, or the address
  /// is out of reach. Returns the reason, or null when it can be offered.
  String? _feeBlocked(Listing l) {
    if (!l.canDeliver) return 'Penyedia belum membuka opsi antar.';
    if ((l.deliveryFee ?? 0) == 0) return 'Ongkirnya sudah gratis.';
    return Validators.delivery(l, _dropPoint().position);
  }

  /// The "+" menu (B10l): "Tawar harga makanan" opens the full offer sheet, "Tawar ongkir" the ongkir-only one.
  Future<void> _showOfferMenu(Listing l) async {
    final blocked = _feeBlocked(l);
    final choice = await showAppSheet<_OfferKind>(
      context: context,
      builder: (ctx) => SheetBody(
        title: 'Tawar',
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OptionRow(
              title: 'Tawar harga makanan',
              subtitle: 'Harga ${formatRupiah(l.price)} per porsi',
              selected: false,
              lead: OptionLead.badge,
              icon: LucideIcons.utensils,
              chevron: true,
              onTap: () => closeSheet(ctx, _OfferKind.food),
            ),
          ),
          OptionRow(
            title: 'Tawar ongkir',
            subtitle: blocked ?? 'Ongkir ${formatRupiah(l.deliveryFee ?? 0)} · ${addressOf(_dropPoint())}',
            selected: false,
            lead: OptionLead.badge,
            icon: LucideIcons.bike,
            chevron: blocked == null,
            enabled: blocked == null,
            onTap: blocked == null ? () => closeSheet(ctx, _OfferKind.fee) : null,
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    await (choice == _OfferKind.food ? _counterOffer(l) : _offerFee(l));
  }

  /// "Tawar ongkir": the food stays where the thread stands (the provider's counter price, else the listed price), only
  /// the delivery fee is offered lower.
  Future<void> _offerFee(Listing l) async {
    final last = ref.read(conversationProvider(widget.conversationId))?.offer;
    final address = _dropPoint();
    final amount = last?.counter ?? l.price;
    final fee = await showFeeOfferSheet(context, listing: l, address: address, amount: amount, fee: last?.counterFee);
    if (fee == null || !mounted) return;
    final error = ref
        .read(chatProvider.notifier)
        .sendOffer(widget.conversationId, amount, portions: (last?.portions ?? 1).clamp(1, l.portionsLeft), delivery: deliveryTo(l, address), deliveryFee: fee);
    if (error != null) {
      showAppSnack(context, error);
    } else {
      _toBottom();
    }
  }

  @override
  void initState() {
    super.initState();
    _toBottom(animate: false);
  }

  @override
  Widget build(BuildContext context) {
    final conv = ref.watch(conversationProvider(widget.conversationId));
    if (conv == null) return const NotFoundScaffold(title: 'Percakapan tidak ditemukan');
    final listing = ref.watch(listingByIdProvider(conv.listingId))!;
    final people = ref.watch(peopleProvider);
    final asReceiver = conv.receiverId == meId;
    final other = people[asReceiver ? conv.providerId : conv.receiverId]!;
    final now = ref.watch(clockProvider)();
    _initial ??= {for (final m in conv.messages) m.id};

    ref.listen<int>(conversationProvider(widget.conversationId).select((c) => c?.messages.length ?? 0), (_, _) => _toBottom());
    // The reservation card grows in after its message; scroll again once it has its full height.
    ref.listen<Object?>(
      conversationProvider(widget.conversationId).select((c) => (c?.pickup?.status, c?.pickup?.payMethod, c?.offer?.status)),
      (_, _) => Future<void>.delayed(Motion.of(context, Motion.slow), () {
        if (mounted) _toBottom();
      }),
    );
    if (conv.unread > 0 || (conv.pickup?.open == true && now.isAfter(conv.pickup!.deadline))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final chat = ref.read(chatProvider.notifier);
        chat.markRead(conv.id);
        chat.expireIfLate(conv.id);
      });
    }

    final pendingOfferForMe = !asReceiver && conv.offer?.status == OfferStatus.pending;
    final waitingForAnswer = asReceiver && conv.offer?.status == OfferStatus.pending;
    final negotiating = asReceiver && !conv.closedSoldOut && conv.pickup == null && !waitingForAnswer;
    final canCounter = negotiating && listing.negotiable && !listing.isFree && !listing.isSoldOut;
    // The last offer was turned down or taken back: the thread says so and offers the next move.
    final declined = canCounter && (conv.offer?.status == OfferStatus.rejected || conv.offer?.status == OfferStatus.cancelled);

    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
                child: Row(
                  children: [
                    RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', fill: AppColors.surface, borderColor: null, onTap: () => context.canPop() ? context.pop() : context.go('/messages')),
                    const SizedBox(width: 4),
                    PersonAvatar(other, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(other.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(18, weight: 700, height: 24)),
                          const SizedBox(height: 2),
                          Align(alignment: Alignment.centerLeft, child: TierTag(other.tier)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                ListingSummaryCard(
                  listing: listing,
                  subtitle: '${listing.isFree ? 'Gratis' : formatRupiah(listing.price)} · sisa ${listing.portionsLeft} porsi · ambil s/d ${formatTime(listing.pickupBy)}',
                  onTap: () => context.push('/listing/${listing.id}'),
                ),
                const SizedBox(height: 14),
                if (conv.messages.isNotEmpty)
                  Center(child: Text(formatDayLabel(conv.messages.first.at, now), style: AppTypography.text(13, weight: 500, color: AppColors.inkMuted))),
                const SizedBox(height: 10),
                for (final m in conv.messages)
                  if (!ChatNotifier.isAcceptanceLine(m))
                    _initial!.contains(m.id)
                        ? _MessageItem(message: m, other: other)
                        : FadeSlideIn(key: ValueKey(m.id), offset: 16, child: _MessageItem(message: m, other: other)),
                if (pendingOfferForMe) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: AppButton(
                        label: 'Tolak',
                        variant: AppButtonVariant.accent,
                        height: 48,
                        onPressed: () async {
                          final ok = await confirmAction(context, title: 'Tolak tawaran ${formatRupiah(conv.offer!.amount)}?', message: '${other.name} akan diberi tahu bahwa tawarannya ditolak.', confirmLabel: 'Tolak');
                          if (ok) ref.read(chatProvider.notifier).rejectOffer(conv.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: AppButton(label: 'Terima ${formatRupiah(conv.offer!.amount)}', height: 48, onPressed: () => ref.read(chatProvider.notifier).acceptOffer(conv.id))),
                  ]),
                ],
                FadeSwitch(
                  child: waitingForAnswer
                      ? _WaitingCard(key: const ValueKey('waiting'), conv: conv, provider: other)
                      : conv.pickup != null
                          ? _ReservationCard(
                              key: ValueKey('${conv.pickup!.status}-${conv.pickup!.payMethod}-${conv.pickup!.paid}'),
                              conv: conv,
                              listing: listing,
                              other: other,
                              asReceiver: asReceiver,
                            )
                          : declined
                              ? _DeclinedCard(
                                  key: ValueKey('declined-${conv.offer!.status}-${conv.offer!.counter}'),
                                  offer: conv.offer!,
                                  listing: listing,
                                  provider: other,
                                  onCounter: () => _counterOffer(listing),
                                  onOfferCounter: () => _offerCounter(listing, conv.offer!),
                                )
                              : const SizedBox(width: double.infinity),
                ),
                if (conv.closedSoldOut && conv.pickup == null) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Text('Makanan ini sudah habis.', style: AppTypography.text(13, color: AppColors.inkMuted)))),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Start: the quick replies hug the left edge (three chips no longer fill the width), the input row stretches.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick replies only while still negotiating; once reserved the card carries the next step.
                if (negotiating)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        AppChip(label: 'Saya OTW', selected: false, height: 44, onTap: () => _quick('Saya OTW')),
                        const SizedBox(width: 8),
                        AppChip(label: 'Masih ada?', selected: false, height: 44, onTap: () => _quick('Masih ada?')),
                        const SizedBox(width: 8),
                        AppChip(label: 'Bisa diantar?', selected: false, height: 44, onTap: () => _quick('Bisa diantar?')),
                      ]),
                    ),
                  ),
                Row(
                  children: [
                    // "+": the two things to haggle over, the food price and the ongkir (B10l).
                    if (canCounter) ...[
                      RoundIconButton(icon: LucideIcons.plus, semanticLabel: 'Tawar', size: 52, onTap: () => _showOfferMenu(listing)),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: !conv.closedSoldOut,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: AppTypography.text(16),
                        cursorColor: AppColors.primary,
                        decoration: InputDecoration(
                          hintText: conv.closedSoldOut ? 'Percakapan ditutup' : 'Tulis pesan...',
                          hintStyle: AppTypography.text(16, color: AppColors.inkMuted),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
                          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    RoundIconButton(
                      iconWidget: const FluentSendIcon(size: 22, color: AppColors.background),
                      semanticLabel: 'Kirim pesan',
                      fill: AppColors.primary,
                      borderColor: null,
                      size: 52,
                      onTap: conv.closedSoldOut ? null : _send,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _quick(String text) {
    ref.read(chatProvider.notifier).sendText(widget.conversationId, text);
    _toBottom();
  }
}

class _MessageItem extends StatelessWidget {
  const _MessageItem({required this.message, required this.other});

  final Message message;
  final Person other;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final own = m.senderId == meId;
    if (m.type == MessageType.system) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text(m.body, textAlign: TextAlign.center, style: AppTypography.text(13, color: AppColors.inkMuted))));
    }
    final align = own ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
    // Everything after the amount: "1 porsi", or "1 porsi · diantar".
    final cut = m.body.indexOf('· ');
    final offerDetail = cut < 0 ? m.body : m.body.substring(cut + 2);
    final bubble = m.type == MessageType.offer
        ? Container(
            width: 252,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: BoxDecoration(
              color: own ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: own ? null : Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(own ? 'Tawaran kamu' : 'Tawaran ${firstName(other.name)}', style: AppTypography.text(14, weight: 600, color: own ? AppColors.onGreenMuted : AppColors.inkMuted)),
                Text(formatRupiah(m.amount ?? 0), style: AppTypography.display(36, height: 44, color: own ? AppColors.background : AppColors.ink)),
                Text(offerDetail, style: AppTypography.text(13, color: own ? AppColors.onGreenMuted : AppColors.inkMuted)),
              ],
            ),
          )
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: own ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: own ? null : Border.all(color: AppColors.border),
              ),
              child: Text(m.body, style: AppTypography.text(15, height: 23, color: own ? AppColors.background : AppColors.ink)),
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          bubble,
          const SizedBox(height: 4),
          Text(formatTime(m.at), style: AppTypography.text(12, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

/// B10j: the offer is out, nothing is reserved yet. The provider "types" while the simulated answer is pending.
class _WaitingCard extends ConsumerWidget {
  const _WaitingCard({super.key, required this.conv, required this.provider});

  final Conversation conv;
  final Person provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            InfoBox(
              'Porsi belum direservasi sampai tawaran diterima.',
              title: 'Menunggu jawaban ${shortName(provider.name)}',
              icon: LucideIcons.info,
              tone: InfoTone.tint,
            ),
            const SizedBox(height: 12),
            const TypingDots(),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () async {
                final ok = await confirmAction(context, title: 'Batalkan tawaranmu?', message: 'Tawaran ke ${shortName(provider.name)} dibatalkan dan kamu bisa menawar lagi nanti.', confirmLabel: 'Batalkan tawaran', cancelLabel: 'Tidak jadi');
                if (ok) ref.read(chatProvider.notifier).cancelOffer(conv.id);
              },
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: AppColors.ink),
              child: Text('Batalkan tawaran', style: AppTypography.text(15, weight: 700)),
            ),
          ],
        ),
      );
}

/// The provider turned the offer down (or the receiver took it back) and nothing is reserved: "Tawar RpX" offers the
/// provider's counter price in one tap, "Tawar lagi" opens "Tulis tawaranmu".
class _DeclinedCard extends StatelessWidget {
  const _DeclinedCard({super.key, required this.offer, required this.listing, required this.provider, required this.onCounter, required this.onOfferCounter});

  final Offer offer;
  final Listing listing;
  final Person provider;
  final VoidCallback onCounter;
  final VoidCallback onOfferCounter;

  @override
  Widget build(BuildContext context) {
    // The ongkir only counts when it is below the provider's: then the food may stay at the full price.
    final fee = offer.delivery == null ? null : offer.counterFee;
    final feeLowered = fee != null && fee < (listing.deliveryFee ?? 0);
    // A counter that is not a valid offer (the full price with the full ongkir) is the "Ambil" button on the detail.
    final counter = offer.status == OfferStatus.rejected && offer.counter != null && Validators.offerAmount(offer.counter, listing.price, feeLowered: feeLowered) == null
        ? offer.counter
        : null;
    final feeWords = !feeLowered ? '' : (fee == 0 ? 'gratis ongkir' : 'ongkir ${formatRupiah(fee)}');
    final name = shortName(provider.name);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoBox(
            counter != null
                ? '$name bisa di harga ${formatRupiah(counter)} per porsi${feeLowered ? ', $feeWords' : ''}. Kamu bisa menawar lagi.'
                : 'Kamu bisa menawar lagi dengan harga lain.',
            title: offer.status == OfferStatus.cancelled ? 'Tawaran dibatalkan' : 'Tawaranmu belum diterima',
            icon: LucideIcons.info,
            tone: InfoTone.tint,
          ),
          if (counter != null) ...[
            const SizedBox(height: 12),
            AppButton(label: 'Tawar ${formatRupiah(counter)}${feeLowered ? ' · $feeWords' : ''}', height: 52, onPressed: onOfferCounter),
          ],
          const SizedBox(height: 12),
          AppButton(label: 'Tawar lagi', icon: LucideIcons.handCoins, height: 52, variant: AppButtonVariant.accent, onPressed: onCounter),
        ],
      ),
    );
  }
}

/// The reservation after "Ambil" or an accepted offer. The receiver picks how to pay, follows the route and scans
/// the provider's QR; the provider opens that QR. No pickup code anywhere.
class _ReservationCard extends ConsumerWidget {
  const _ReservationCard({super.key, required this.conv, required this.listing, required this.other, required this.asReceiver});

  final Conversation conv;
  final Listing listing;
  final Person other;
  final bool asReceiver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickup = conv.pickup!;
    final unit = conv.offer?.amount ?? listing.price; // per porsi
    final portions = conv.offer?.portions ?? 1;
    final amount = unit * portions;
    // "Minta diantar": the provider brings the food to [drop], and the fee comes on top of the food.
    final drop = conv.offer?.delivery;
    final total = amount + (drop?.fee ?? 0);
    final deadline = formatTime(pickup.deadline);
    final providerShort = shortName(asReceiver ? other.name : listing.provider.name);
    final otherFirst = firstName(other.name);
    // What the receiver really pays: the agreed price plus the delivery fee, minus a food voucher applied on Pembayaran.
    final payable = total - pickup.discount;
    final claimedFull = unit == listing.price;
    final portionsNote = portions > 1 ? ' · $portions porsi' : '';
    // Only the ongkir was haggled (the food is at the listed price, the fee below the provider's): the card says so.
    final feeHaggled = drop != null && conv.offer?.status == OfferStatus.accepted && claimedFull && drop.fee < (listing.deliveryFee ?? 0);
    final acceptedTitle = feeHaggled
        ? (drop.fee == 0 ? 'Gratis ongkir disetujui' : 'Ongkir ${formatRupiah(drop.fee)} disetujui')
        : amount == 0
            ? 'Ambil gratis disetujui'
            : (claimedFull ? 'Ambil ${formatRupiah(unit)} disetujui' : 'Tawaran ${formatRupiah(unit)} diterima$portionsNote');

    late final String title;
    late final String body;
    String? tag;
    final actions = <Widget>[];
    void primary(String label, VoidCallback onTap, {IconData? icon}) => actions.add(AppButton(label: label, icon: icon, height: 52, onPressed: onTap));
    void outline(String label, VoidCallback onTap, {IconData? icon}) => actions.add(AppButton(label: label, icon: icon, height: 52, variant: AppButtonVariant.outline, onPressed: onTap));

    switch (pickup.status) {
      case PickupStatus.pickedUp:
        title = 'Makanan sudah diambil';
        body = asReceiver ? 'QR sudah dipindai. Selamat menikmati!' : 'Poin sudah ditambahkan ke profilmu.';
        if (asReceiver && conv.review == null) primary('Beri ulasan', () => context.push('/review/${conv.id}'));
      case PickupStatus.expired || PickupStatus.cancelled:
        title = 'Reservasi kedaluwarsa';
        body = 'Waktu ambil sudah lewat pukul $deadline. Porsinya dibuka lagi untuk orang lain.';
        if (asReceiver) primary('Cari makanan lain', () => context.go('/'));
      case PickupStatus.reserved:
        title = acceptedTitle;
        if (!asReceiver) {
          final pay = total == 0
              ? ''
              : pickup.paid
                  ? ' Sudah dibayar ${formatRupiah(payable)} via QRIS.'
                  : pickup.payMethod == PayMethod.cash
                      ? ' Terima ${formatRupiah(payable)} tunai di tempat.'
                      : ' $otherFirst belum memilih cara bayar.';
          body = drop == null
              ? 'Tunjukkan QR ke $otherFirst saat dia mengambil, sebelum $deadline.$pay'
              : 'Antar ke $otherFirst di ${drop.address} sebelum $deadline. Tunjukkan QR saat sampai.$pay';
          primary('Buka QR ambil', () => context.push('/qr/${conv.id}'), icon: LucideIcons.qrCode);
          // The provider walks the food over: the same route screen, to the delivery address.
          if (drop != null) outline('Lihat rute antar', () => context.push('/route/${conv.id}'), icon: LucideIcons.personStanding);
        } else if (total > 0 && pickup.payMethod == null) {
          // Free food with a delivery fee still has something to pay.
          body = 'Pilih cara bayar: tunai di tempat atau bayar di aplikasi. Reservasi aman sampai $deadline.';
          if (drop == null) outline('Lihat rute', () => context.push('/route/${conv.id}'), icon: LucideIcons.personStanding);
          primary('Pilih cara bayar', () => context.push('/pay/${conv.id}'));
        } else {
          final scanLine = drop == null ? 'Pindai QR di HP $providerShort saat tiba, sebelum $deadline.' : 'Pindai QR di HP $providerShort saat makanan sampai, sebelum $deadline.';
          if (pickup.paid) {
            tag = 'Lunas';
            body = 'Lunas ${formatRupiah(payable)} via QRIS. $scanLine';
          } else if (total == 0) {
            body = 'Gratis. $scanLine';
          } else {
            body = 'Bayar ${formatRupiah(payable)} tunai di tempat. $scanLine';
          }
          primary('Pindai QR', () => context.push('/scan/${conv.id}'));
          // A delivery comes to the receiver: there is no walk to plan.
          if (drop == null) outline('Lihat rute', () => context.push('/route/${conv.id}'), icon: LucideIcons.personStanding);
        }
    }

    final done = pickup.status == PickupStatus.pickedUp;
    final expired = pickup.status == PickupStatus.expired || pickup.status == PickupStatus.cancelled;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: expired ? AppColors.surfaceSand : AppColors.successTint, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: expired ? AppColors.accentInk : AppColors.primary, shape: BoxShape.circle),
              child: Icon(expired ? LucideIcons.clock : LucideIcons.check, size: 20, color: AppColors.background),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTypography.display(18, weight: 700, height: 24))),
            if (tag != null) Pill(tag, fill: AppColors.primary, color: AppColors.background, height: 26, weight: 700),
          ]),
          const SizedBox(height: 12),
          Text(body, style: AppTypography.text(15, height: 22)),
          if (!done && !expired && asReceiver && pickup.payMethod != null || (!done && !expired && total == 0 && asReceiver)) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.mapPin, size: 16, color: AppColors.primary)),
              const SizedBox(width: 6),
              Expanded(child: Text(drop == null ? 'Titik ambil: ${listing.pickupPoint}' : 'Alamat antar: ${drop.address}', style: AppTypography.text(13, height: 18, color: AppColors.inkMuted))),
            ]),
          ],
          if (!done && !expired && asReceiver && listing.bringsContainer) ...[
            const SizedBox(height: 8),
            PackagingNote(listing.packaging, compact: true),
          ],
          if (done && asReceiver && conv.review != null) ...[
            const SizedBox(height: 8),
            Text('Ulasanmu terkirim. Terima kasih!', style: AppTypography.text(15, weight: 600, color: AppColors.primary)),
          ],
          for (final a in actions) ...[const SizedBox(height: 12), a],
        ],
      ),
    );
  }
}
