import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/chat_repository.dart';
import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/mock/mock_data.dart';
import '../../core/models/conversation.dart';
import '../../core/models/enums.dart';
import '../../core/models/listing.dart';
import '../../core/models/person.dart';
import '../../core/services/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/listing_photo.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';
import 'offer_sheet.dart';

/// B10 Chat negosiasi: listing card, offer cards, bubbles, the accepted card with the pickup code,
/// quick replies and the composer. The other party is simulated.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

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
      animate ? _scroll.animateTo(end, duration: const Duration(milliseconds: 220), curve: Curves.easeOut) : _scroll.jumpTo(end);
    });
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    ref.read(chatProvider.notifier).sendText(widget.conversationId, text);
    _input.clear();
    _toBottom();
  }

  Future<void> _counterOffer(Listing l) async {
    final amount = await showOfferSheet(context, price: l.price);
    if (amount == null || !mounted) return;
    final error = ref.read(chatProvider.notifier).sendOffer(widget.conversationId, amount);
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
    if (conv == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Percakapan tidak ditemukan')));
    final listing = ref.watch(listingByIdProvider(conv.listingId))!;
    final people = ref.watch(peopleProvider);
    final asReceiver = conv.receiverId == meId;
    final other = people[asReceiver ? conv.providerId : conv.receiverId]!;
    final now = ref.watch(clockProvider)();

    ref.listen<int>(conversationProvider(widget.conversationId).select((c) => c?.messages.length ?? 0), (_, _) => _toBottom());
    if (conv.unread > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(chatProvider.notifier).markRead(conv.id);
      });
    }

    final pendingOfferForMe = !asReceiver && conv.offer?.status == OfferStatus.pending;
    final canQuickReply = asReceiver && !conv.closedSoldOut && conv.pickup?.status != PickupStatus.pickedUp;
    final canCounter = canQuickReply && conv.pickup == null && listing.negotiable && !listing.isFree;

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
                _ListingCard(listing: listing),
                const SizedBox(height: 14),
                if (conv.messages.isNotEmpty)
                  Center(child: Text(formatDayLabel(conv.messages.first.at, now), style: AppTypography.text(13, weight: 500, color: AppColors.inkMuted))),
                const SizedBox(height: 10),
                for (final m in conv.messages) _MessageItem(message: m, conv: conv, other: other),
                if (pendingOfferForMe) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: AppButton(label: 'Tolak', variant: AppButtonVariant.accent, height: 48, onPressed: () => ref.read(chatProvider.notifier).rejectOffer(conv.id))),
                    const SizedBox(width: 12),
                    Expanded(child: AppButton(label: 'Terima ${formatRupiah(conv.offer!.amount)}', height: 48, onPressed: () => ref.read(chatProvider.notifier).acceptOffer(conv.id))),
                  ]),
                ],
                if (conv.pickup != null) _AcceptedCard(conv: conv, listing: listing, other: other, asReceiver: asReceiver),
                if (conv.closedSoldOut && conv.pickup == null) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Text('Makanan ini sudah habis.', style: AppTypography.text(13, color: AppColors.inkMuted)))),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canQuickReply)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        AppChip(label: 'Saya OTW', selected: false, height: 42, onTap: () => _quick('Saya OTW')),
                        const SizedBox(width: 8),
                        AppChip(label: 'Masih ada?', selected: false, height: 42, onTap: () => _quick('Masih ada?')),
                        if (canCounter) ...[
                          const SizedBox(width: 8),
                          AppChip(label: 'Tawar lagi', selected: false, height: 42, accentWhenUnselected: true, onTap: () => _counterOffer(listing)),
                        ],
                      ]),
                    ),
                  ),
                Row(
                  children: [
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
                    RoundIconButton(icon: LucideIcons.navigation, semanticLabel: 'Kirim pesan', fill: AppColors.primary, borderColor: null, iconColor: AppColors.background, size: 52, onTap: conv.closedSoldOut ? null : _send),
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

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/listing/${listing.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ListingPhoto(listing, width: 56, height: 56, radius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.display(16, weight: 700, height: 21)),
                      Text(
                        '${listing.isFree ? 'Gratis' : formatRupiah(listing.price)} · sisa ${listing.portionsLeft} porsi · ambil s/d ${formatTime(listing.pickupBy)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.text(13, height: 18, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 22, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      );
}

class _MessageItem extends StatelessWidget {
  const _MessageItem({required this.message, required this.conv, required this.other});

  final Message message;
  final Conversation conv;
  final Person other;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final own = m.senderId == meId;
    if (m.type == MessageType.system) {
      if (m.body.contains('Kode ambil')) return const SizedBox.shrink(); // shown as the accepted card
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text(m.body, style: AppTypography.text(13, color: AppColors.inkMuted))));
    }
    final align = own ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
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
                Text(own ? 'Tawaran kamu' : 'Tawaran ${other.name.split(' ').first}', style: AppTypography.text(14, weight: 600, color: own ? AppColors.onGreenMuted : AppColors.inkMuted)),
                Text(formatRupiah(m.amount ?? 0), style: AppTypography.display(36, height: 44, color: own ? AppColors.background : AppColors.ink)),
                Text(m.body.contains('·') ? '${m.body.split('· ').last} · ambil jalan kaki' : m.body, style: AppTypography.text(13, color: own ? AppColors.onGreenMuted : AppColors.inkMuted)),
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

/// "Tawaran Rp4.000 diterima" with the pickup code. The receiver confirms with "Sudah saya ambil".
class _AcceptedCard extends ConsumerWidget {
  const _AcceptedCard({required this.conv, required this.listing, required this.other, required this.asReceiver});

  final Conversation conv;
  final Listing listing;
  final Person other;
  final bool asReceiver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickup = conv.pickup!;
    final picked = pickup.status == PickupStatus.pickedUp;
    final amount = conv.offer?.amount ?? listing.price;
    final priceText = amount == 0 ? 'gratis' : formatRupiah(amount);
    final title = picked ? 'Makanan sudah diambil' : (amount == 0 ? 'Ambil gratis disetujui' : 'Tawaran ${formatRupiah(amount)} diterima');
    final body = asReceiver
        ? 'Tunjukkan kode ini ke ${shortName(other.name == listing.provider.name ? listing.provider.name : other.name)} saat mengambil.${amount == 0 ? '' : ' Bayar ${formatRupiah(amount)} di tempat.'}'
        : 'Minta ${other.name.split(' ').first} menunjukkan kode ini saat mengambil.${amount == 0 ? '' : ' Terima pembayaran $priceText di tempat.'}';
    final notifier = ref.read(chatProvider.notifier);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(LucideIcons.check, size: 20, color: AppColors.background)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTypography.display(18, weight: 700, height: 24))),
          ]),
          if (!picked) ...[
            const SizedBox(height: 12),
            Text(body, style: AppTypography.text(15, height: 22)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.mapPin, size: 16, color: AppColors.primary)),
              const SizedBox(width: 6),
              Expanded(child: Text('Titik ambil: ${listing.pickupPoint}', style: AppTypography.text(13, height: 18, color: AppColors.inkMuted))),
            ]),
            const SizedBox(height: 14),
            Row(
              children: [
                Semantics(
                  label: 'Kode ambil ${pickup.code}',
                  child: Container(
                    width: 146,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                    child: Text(pickup.code, style: AppTypography.display(20, weight: 800).copyWith(letterSpacing: 2)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: asReceiver ? 'Sudah saya ambil' : 'Tandai diambil',
                    height: 52,
                    textSize: 15,
                    onPressed: () {
                      notifier.markPickedUp(conv.id);
                      if (asReceiver) context.push('/review/${conv.id}');
                    },
                  ),
                ),
              ],
            ),
          ] else if (asReceiver) ...[
            const SizedBox(height: 12),
            if (conv.review == null) AppButton(label: 'Beri ulasan', height: 52, onPressed: () => context.push('/review/${conv.id}')) else Text('Ulasanmu terkirim. Terima kasih!', style: AppTypography.text(15, weight: 600, color: AppColors.primary)),
          ] else ...[
            const SizedBox(height: 8),
            Text('Poin sudah ditambahkan ke profilmu.', style: AppTypography.text(14, color: AppColors.primary)),
          ],
        ],
      ),
    );
  }
}
