import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_data.dart';
import '../models/conversation.dart';
import '../models/enums.dart';
import '../models/listing.dart';
import '../services/formatters.dart';
import '../services/negotiation.dart';
import '../services/points.dart';
import '../services/validators.dart';
import 'listings_repository.dart';
import 'providers.dart';
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

  /// Receiver sends an offer. Returns an error message when the amount is invalid.
  String? sendOffer(String id, int amount, {int portions = 1}) {
    final c = byId(id);
    if (c == null) return 'Percakapan tidak ditemukan';
    final l = _listing(c.listingId);
    final error = Validators.offerAmount(amount, l.price);
    if (error != null) return error;
    _update(
      id,
      (c) => c.copyWith(
        offer: Offer(id: 'o_$id', listingId: c.listingId, receiverId: meId, amount: amount, portions: portions),
        messages: [...c.messages, _msg(meId, MessageType.offer, 'Tawaran ${formatRupiah(amount)} · $portions porsi', amount: amount)],
      ),
    );
    _resolveOffer(id);
    return null;
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

  String _newCode() {
    final used = {for (final c in state) c.pickup?.code};
    final rnd = ref.read(randomProvider);
    var code = generatePickupCode(rnd);
    while (used.contains(code)) {
      code = generatePickupCode(rnd);
    }
    return code;
  }

  /// Accepts the pending offer: creates the pickup code and the system message.
  void _accept(String id, {required String from}) {
    final c = byId(id)!;
    final l = _listing(c.listingId);
    final offer = c.offer!;
    final code = _newCode();
    final amount = offer.amount;
    final isMe = from == meId;
    final speech = isMe ? 'Boleh, silakan ambil sebelum ${formatTime(l.pickupBy)} ya.' : 'Boleh, Mas. Ambil sebelum ${formatTime(l.pickupBy)} ya.';
    final system = amount == 0 ? 'Ambil gratis disetujui. Kode ambil $code.' : 'Tawaran ${formatRupiah(amount)} diterima. Kode ambil $code.';
    _update(
      id,
      (c) => c.copyWith(
        offer: offer.copyWith(status: OfferStatus.accepted),
        pickup: Pickup(id: 'pk_$id', code: code),
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

  /// "Ambil · RpX": takes the food at the listed price, no negotiation. Returns the thread id.
  String claim(String listingId) {
    final id = openForListing(listingId);
    final c = byId(id)!;
    if (c.pickup != null) return id;
    final l = _listing(listingId);
    _update(
      id,
      (c) => c.copyWith(
        offer: Offer(id: 'o_$id', listingId: listingId, receiverId: meId, amount: l.price),
        messages: [...c.messages, _msg(meId, MessageType.text, 'Saya ambil ya.')],
      ),
    );
    final code = _newCode();
    final system = l.isFree ? 'Ambil gratis disetujui. Kode ambil $code.' : 'Ambil ${formatRupiah(l.price)} disetujui. Kode ambil $code.';
    _update(
      id,
      (c) => c.copyWith(
        offer: c.offer!.copyWith(status: OfferStatus.accepted),
        pickup: Pickup(id: 'pk_$id', code: code),
        messages: [...c.messages, _msg('system', MessageType.system, system)],
      ),
    );
    _counterpartSays(id, 'Siap, silakan ambil sebelum ${formatTime(l.pickupBy)} ya.');
    return id;
  }

  /// "Sudah saya ambil" (receiver) or "Tandai sudah diambil" (provider).
  void markPickedUp(String id) {
    final c = byId(id);
    if (c == null || c.pickup == null || c.pickup!.status != PickupStatus.waiting) return;
    final portions = c.offer?.portions ?? 1;
    final l = _listing(c.listingId);
    _update(
      id,
      (c) => c.copyWith(
        pickup: c.pickup!.copyWith(status: PickupStatus.pickedUp, pickedUpAt: _now),
        messages: [...c.messages, _msg('system', MessageType.system, 'Makanan sudah diambil.')],
      ),
    );
    ref.read(listingsProvider.notifier).consume(c.listingId, portions);
    final session = ref.read(sessionProvider.notifier);
    if (c.receiverId == meId) {
      session.addSaved(portions);
    } else {
      session.addShared(portions);
      session.addPoints(pickupPoints(portions: portions, isFree: (c.offer?.amount ?? l.price) == 0));
    }
  }

  void submitReview(String id, Review review) => _update(id, (c) => c.copyWith(review: review));
}

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
