import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_data.dart';
import '../models/conversation.dart';
import '../models/enums.dart';
import '../models/listing.dart';
import '../models/person.dart';
import '../services/formatters.dart';
import '../services/negotiation.dart';
import '../services/points.dart';
import '../services/validators.dart';
import 'listings_repository.dart';
import 'providers.dart';
import 'rewards_repository.dart';
import 'session_repository.dart';

/// Conversations, offers, pickups and reviews. The other party is simulated: replies arrive after
/// [simulatedReplyDelayProvider]. All rules mirror ARCHITECTURE.md (Claim flow).
class ChatNotifier extends Notifier<List<Conversation>> {
  var _seq = 0;

  @override
  List<Conversation> build() => ref.read(mockDataProvider).conversations;

  DateTime get _now => ref.read(clockProvider)();
  Duration get _delay => ref.read(simulatedReplyDelayProvider);

  Conversation? byId(String id) {
    for (final c in state) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The receiver-side thread for a listing, if the user already opened one.
  Conversation? forListing(String listingId) {
    for (final c in state) {
      if (c.listingId == listingId && c.receiverId == meId) return c;
    }
    return null;
  }

  Listing _listing(String id) => ref.read(listingsProvider.notifier).byId(id)!;

  void _update(String id, Conversation Function(Conversation c) f) {
    state = [for (final c in state) c.id == id ? f(c) : c];
  }

  Message _msg(String sender, MessageType type, String body, {int? amount}) =>
      Message(id: 'm${_seq++}_${_now.microsecondsSinceEpoch}', senderId: sender, type: type, body: body, at: _now, amount: amount);

  String _otherParty(Conversation c) => c.receiverId == meId ? c.providerId : c.receiverId;

  /// Opens (or creates) the receiver thread for a listing and returns its id.
  String openForListing(String listingId) {
    final existing = forListing(listingId);
    if (existing != null) return existing.id;
    final l = _listing(listingId);
    final id = 'c_${listingId}_${state.length + 1}';
    state = [...state, Conversation(id: id, listingId: listingId, receiverId: meId, providerId: l.provider.id)];
    return id;
  }

  void markRead(String id) {
    final c = byId(id);
    if (c != null && c.unread > 0) _update(id, (c) => c.copyWith(unread: 0));
  }

  void _addMessage(String id, Message m, {bool unread = false}) =>
      _update(id, (c) => c.copyWith(messages: [...c.messages, m], unread: unread ? c.unread + 1 : c.unread));

  Future<void> _counterpartSays(String id, String body) async {
    await Future<void>.delayed(_delay);
    final c = byId(id);
    if (c == null) return;
    _addMessage(id, _msg(_otherParty(c), MessageType.text, body), unread: true);
  }

  void sendText(String id, String text) {
    final body = text.trim();
    final c = byId(id);
    if (body.isEmpty || c == null) return;
    _addMessage(id, _msg(meId, MessageType.text, body));
    final lower = body.toLowerCase();
    final l = _listing(c.listingId);
    final reply = lower.contains('otw')
        ? 'Siap, saya tunggu ya.'
        : lower.contains('masih ada')
            ? (l.isSoldOut ? 'Maaf, sudah habis.' : 'Masih ada ${l.portionsLeft} porsi, silakan.')
            : 'Oke, noted ya.';
    _counterpartSays(id, reply);
  }

  /// Receiver sends an offer, optionally with a note for the provider. Returns an error message when the amount is
  /// invalid. Nothing is reserved until the provider accepts (B10j "Menunggu jawaban").
  String? sendOffer(String id, int amount, {int portions = 1, String message = ''}) {
    final c = byId(id);
    if (c == null) return 'Percakapan tidak ditemukan';
    final l = _listing(c.listingId);
    final error = Validators.offerAmount(amount, l.price);
    if (error != null) return error;
    final note = message.trim();
    _update(
      id,
      (c) => c.copyWith(
        offer: Offer(id: 'o_$id', listingId: c.listingId, receiverId: meId, amount: amount, portions: portions),
        messages: [
          ...c.messages,
          _msg(meId, MessageType.offer, 'Tawaran ${formatRupiah(amount)} · $portions porsi', amount: amount),
          if (note.isNotEmpty) _msg(meId, MessageType.text, note),
        ],
      ),
    );
    _resolveOffer(id);
    return null;
  }

  /// "Batalkan tawaran" while the provider has not answered yet.
  void cancelOffer(String id) {
    final c = byId(id);
    if (c?.offer?.status != OfferStatus.pending) return;
    _update(id, (c) => c.copyWith(offer: c.offer!.copyWith(status: OfferStatus.cancelled)));
    _addMessage(id, _msg('system', MessageType.system, 'Tawaran dibatalkan.'));
  }

  Future<void> _resolveOffer(String id) async {
    await Future<void>.delayed(_delay);
    final c = byId(id);
    if (c == null || c.offer?.status != OfferStatus.pending) return;
    final l = _listing(c.listingId);
    switch (decideOffer(price: l.price, amount: c.offer!.amount, negotiable: l.negotiable)) {
      case OfferAccepted():
        _accept(id, from: c.providerId);
      case OfferCountered(:final amount):
        _update(id, (c) => c.copyWith(offer: c.offer!.copyWith(status: OfferStatus.rejected)));
        _addMessage(id, _msg(c.providerId, MessageType.text, 'Maaf, paling rendah ${formatRupiah(amount)} ya.'), unread: true);
    }
  }

  /// System line behind the accepted card (hidden in the chat, the card shows it).
  static bool isAcceptanceLine(Message m) => m.type == MessageType.system && (m.body.endsWith(' diterima.') || m.body.endsWith(' disetujui.'));

  /// Accepts the pending offer and reserves the portions until the pickup deadline.
  void _accept(String id, {required String from}) {
    final c = byId(id)!;
    final l = _listing(c.listingId);
    final offer = c.offer!;
    final amount = offer.amount;
    final isMe = from == meId;
    final speech = isMe ? 'Boleh, silakan ambil sebelum ${formatTime(l.pickupBy)} ya.' : 'Boleh, Mas. Ambil sebelum ${formatTime(l.pickupBy)} ya.';
    final system = amount == 0 ? 'Ambil gratis disetujui.' : 'Tawaran ${formatRupiah(amount)} diterima.';
    _update(
      id,
      (c) => c.copyWith(
        offer: offer.copyWith(status: OfferStatus.accepted),
        pickup: Pickup(id: 'pk_$id', deadline: l.pickupBy),
        messages: [...c.messages, _msg(from, MessageType.text, speech), _msg('system', MessageType.system, system)],
        unread: isMe ? c.unread : c.unread + 1,
      ),
    );
  }

  /// Provider side: accept the receiver's pending offer.
  void acceptOffer(String id) {
    final c = byId(id);
    if (c?.offer?.status == OfferStatus.pending) _accept(id, from: meId);
  }

  void rejectOffer(String id) {
    final c = byId(id);
    if (c?.offer?.status != OfferStatus.pending) return;
    _update(id, (c) => c.copyWith(offer: c.offer!.copyWith(status: OfferStatus.rejected)));
    _addMessage(id, _msg(meId, MessageType.text, 'Maaf, belum bisa di harga itu ya.'));
  }

  /// "Ambil · RpX": reserves the food at the listed price, no negotiation. Returns the thread id.
  String claim(String listingId) {
    final id = openForListing(listingId);
    final c = byId(id)!;
    if (c.pickup != null && c.pickup!.open) return id;
    final l = _listing(listingId);
    final system = l.isFree ? 'Ambil gratis disetujui.' : 'Ambil ${formatRupiah(l.price)} disetujui.';
    _update(
      id,
      (c) => c.copyWith(
        offer: Offer(id: 'o_$id', listingId: listingId, receiverId: meId, amount: l.price, status: OfferStatus.accepted),
        pickup: Pickup(id: 'pk_$id', deadline: l.pickupBy),
        messages: [...c.messages, _msg(meId, MessageType.text, 'Saya ambil ya.'), _msg('system', MessageType.system, system)],
      ),
    );
    _counterpartSays(id, 'Siap, silakan ambil sebelum ${formatTime(l.pickupBy)} ya.');
    return id;
  }

  /// Agreed price of the thread (offer amount, or the listed price).
  int amountOf(Conversation c) => c.offer?.amount ?? _listing(c.listingId).price;

  /// "Pakai tunai di tempat" / "Bayar RpX" on B10d-B10e.
  void choosePayment(String id, PayMethod method) {
    final c = byId(id);
    if (c?.pickup == null || !c!.pickup!.open || c.pickup!.paid) return;
    _update(id, (c) => c.copyWith(pickup: c.pickup!.copyWith(payMethod: method)));
    _spendVoucher(c.pickup!);
    if (method == PayMethod.cash) _addMessage(id, _msg('system', MessageType.system, 'Kamu memilih bayar tunai di tempat.'));
  }

  /// A payment is never lower than this, so a voucher can not make the food free.
  static const minPayable = 1000;

  /// Uses a food voucher on Pembayaran. Returns an Indonesian error, or null when it is applied. The voucher stays unused until the
  /// payment is confirmed ([choosePayment] with cash, or QRIS paid), so removing it or an expired reservation keeps it usable.
  String? applyVoucher(String id, String code) {
    final c = byId(id);
    final p = c?.pickup;
    if (c == null || p == null || !p.open) return 'Reservasi tidak aktif.';
    if (p.payMethod != null || p.paid) return 'Cara bayar sudah dipilih.';
    final price = amountOf(c);
    if (price <= 0) return 'Makanan gratis tidak perlu voucher.';
    final v = ref.read(myVouchersProvider.notifier).byCode(code);
    if (v == null) return 'Kode tidak ditemukan.';
    if (v.used) return 'Voucher sudah dipakai.';
    if (!v.validUntil.isAfter(_now)) return 'Voucher sudah kedaluwarsa.';
    if (!v.reward.isFoodVoucher) return 'Voucher ini untuk mitra, tidak berlaku untuk makanan.';
    final off = math.min(v.reward.foodDiscount, price - minPayable);
    if (off <= 0) return 'Harga makanan terlalu kecil untuk memakai voucher.';
    _update(id, (c) => c.copyWith(pickup: c.pickup!.withVoucher(v.code, off)));
    return null;
  }

  /// "✕" next to the voucher on Pembayaran.
  void removeVoucher(String id) {
    final c = byId(id);
    final p = c?.pickup;
    if (p == null || p.voucherCode == null || p.payMethod != null || p.paid) return;
    _update(id, (c) => c.copyWith(pickup: c.pickup!.withVoucher(null, 0)));
  }

  void _spendVoucher(Pickup p) {
    final code = p.voucherCode;
    if (code != null) ref.read(myVouchersProvider.notifier).markUsed(code);
  }

  /// "Cek status pembayaran" on B10f. The mock gateway reports the payment on the second check (B10f2, then B10g).
  bool checkQrisPayment(String id) {
    final c = byId(id);
    final p = c?.pickup;
    if (p == null || !p.open) return false;
    if (p.paid) return true;
    if (p.statusChecks == 0) {
      _update(id, (c) => c.copyWith(pickup: p.copyWith(statusChecks: 1)));
      return false;
    }
    _update(
      id,
      (c) => c.copyWith(
        pickup: p.copyWith(statusChecks: p.statusChecks + 1, paidAt: _now, payMethod: PayMethod.qris),
        messages: [...c.messages, _msg('system', MessageType.system, 'Pembayaran ${formatRupiah(amountOf(c) - p.discount)} via QRIS berhasil.')],
      ),
    );
    _spendVoucher(p);
    return true;
  }

  /// Expires the reservation when its deadline passed; the portions open up again. Returns true when expired.
  bool expireIfLate(String id) {
    final c = byId(id);
    final p = c?.pickup;
    if (p == null) return false;
    if (p.status == PickupStatus.expired) return true;
    if (!p.open || !_now.isAfter(p.deadline)) return false;
    _update(
      id,
      (c) => c.copyWith(
        pickup: p.copyWith(status: PickupStatus.expired),
        messages: [...c.messages, _msg('system', MessageType.system, 'Reservasi kedaluwarsa.')],
      ),
    );
    return true;
  }

  /// The receiver's scan of the provider's QR (B10b), or the mock receiver scanning the user's QR (C17). Only works
  /// inside the pickup window; afterwards the reservation expires. Marks the food picked up and awards points.
  ScanOutcome scanQr(String id) {
    final c = byId(id);
    if (c == null || c.pickup == null) return ScanOutcome.invalid;
    if (c.pickup!.status == PickupStatus.pickedUp) return ScanOutcome.alreadyUsed;
    if (expireIfLate(id)) return ScanOutcome.expired;
    if (!c.pickup!.open) return ScanOutcome.invalid;
    final portions = c.offer?.portions ?? 1;
    final people = ref.read(peopleProvider);
    final line = c.receiverId == meId
        ? 'QR dipindai. Makanan diambil dari ${people[c.providerId]?.name ?? 'penyedia'}.'
        : 'Makanan diambil ${people[c.receiverId]?.name.split(' ').first ?? 'penerima'}.';
    _update(
      id,
      (c) => c.copyWith(
        pickup: c.pickup!.copyWith(status: PickupStatus.pickedUp, pickedUpAt: _now),
        messages: [...c.messages, _msg('system', MessageType.system, line)],
      ),
    );
    ref.read(listingsProvider.notifier).consume(c.listingId, portions);
    final session = ref.read(sessionProvider.notifier);
    if (c.receiverId == meId) {
      session.addSaved(portions);
    } else {
      session.addShared(portions);
      session.addPoints(pickupPoints(portions: portions, isFree: amountOf(c) == 0));
    }
    return ScanOutcome.ok;
  }

  void submitReview(String id, Review review) => _update(id, (c) => c.copyWith(review: review));
}

enum ScanOutcome { ok, expired, alreadyUsed, invalid }

final chatProvider = NotifierProvider<ChatNotifier, List<Conversation>>(ChatNotifier.new);

final conversationProvider = Provider.family<Conversation?, String>((ref, id) {
  for (final c in ref.watch(chatProvider)) {
    if (c.id == id) return c;
  }
  return null;
});

/// Threads where the user is the receiver ("Saya menerima") or the provider ("Saya berbagi"), newest first.
final receivedThreadsProvider = Provider<List<Conversation>>((ref) => _sorted(ref.watch(chatProvider).where((c) => c.receiverId == meId)));
final sharedThreadsProvider = Provider<List<Conversation>>((ref) => _sorted(ref.watch(chatProvider).where((c) => c.providerId == meId)));

List<Conversation> _sorted(Iterable<Conversation> cs) {
  final list = cs.toList()..sort((a, b) => (b.last?.at ?? DateTime(0)).compareTo(a.last?.at ?? DateTime(0)));
  return list;
}

/// Everything a pickup or payment screen needs about one reserved thread.
class ReservationInfo {
  const ReservationInfo({required this.conv, required this.listing, required this.provider, required this.receiver});

  final Conversation conv;
  final Listing listing;
  final Person provider;
  final Person receiver;

  Pickup get pickup => conv.pickup!;
  int get amount => conv.offer?.amount ?? listing.price;

  /// Rupiah the food voucher takes off, and what the receiver really pays ([amount] minus the voucher).
  int get discount => pickup.discount;
  int get payable => amount - discount;
  int get portions => conv.offer?.portions ?? 1;
  bool get asReceiver => conv.receiverId == meId;
}

final reservationProvider = Provider.family<ReservationInfo?, String>((ref, id) {
  final conv = ref.watch(conversationProvider(id));
  if (conv == null || conv.pickup == null) return null;
  final listing = ref.watch(listingByIdProvider(conv.listingId));
  final people = ref.watch(peopleProvider);
  final provider = people[conv.providerId];
  final receiver = people[conv.receiverId];
  if (listing == null || provider == null || receiver == null) return null;
  return ReservationInfo(conv: conv, listing: listing, provider: provider, receiver: receiver);
});
