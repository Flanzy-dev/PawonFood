import 'enums.dart';

class Message {
  const Message({required this.id, required this.senderId, required this.type, required this.body, required this.at, this.amount});

  final String id;
  final String senderId;
  final MessageType type;
  final String body;
  final DateTime at;

  /// Offer amount in rupiah (only for [MessageType.offer]).
  final int? amount;
}

class Offer {
  const Offer({required this.id, required this.listingId, required this.receiverId, required this.amount, this.portions = 1, this.status = OfferStatus.pending});

  final String id;
  final String listingId;
  final String receiverId;
  final int amount;
  final int portions;
  final OfferStatus status;

  Offer copyWith({OfferStatus? status, int? amount}) =>
      Offer(id: id, listingId: listingId, receiverId: receiverId, amount: amount ?? this.amount, portions: portions, status: status ?? this.status);
}

class Pickup {
  const Pickup({required this.id, required this.code, this.status = PickupStatus.waiting, this.pickedUpAt});

  final String id;

  /// `PWN-XXXX`, generated on the (mock) server and shown only to receiver and provider.
  final String code;
  final PickupStatus status;
  final DateTime? pickedUpAt;

  Pickup copyWith({PickupStatus? status, DateTime? pickedUpAt}) =>
      Pickup(id: id, code: code, status: status ?? this.status, pickedUpAt: pickedUpAt ?? this.pickedUpAt);
}

class Review {
  const Review({required this.pickupId, required this.rating, this.tags = const [], this.comment = ''});

  final String pickupId;
  final int rating;
  final List<String> tags;
  final String comment;
}

/// Label shown on a thread row in Pesan.
enum ThreadStatus {
  waiting('Menunggu balasan'),
  accepted('Tawaran diterima'),
  ready('Siap diambil'),
  done('Selesai'),
  soldOut('Habis');

  const ThreadStatus(this.label);
  final String label;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.listingId,
    required this.receiverId,
    required this.providerId,
    this.messages = const [],
    this.offer,
    this.pickup,
    this.unread = 0,
    this.review,
    this.closedSoldOut = false,
  });

  final String id;
  final String listingId;
  final String receiverId;
  final String providerId;
  final List<Message> messages;
  final Offer? offer;
  final Pickup? pickup;
  final int unread;
  final Review? review;

  /// True when the listing ran out before this thread finished.
  final bool closedSoldOut;

  Message? get last => messages.isEmpty ? null : messages.last;

  /// Last human message (falls back to the last message when there is none); shown on thread rows.
  Message? get lastChat {
    for (final m in messages.reversed) {
      if (m.type != MessageType.system) return m;
    }
    return last;
  }

  ThreadStatus get status {
    if (pickup?.status == PickupStatus.pickedUp) return ThreadStatus.done;
    if (closedSoldOut && pickup == null) return ThreadStatus.soldOut;
    if (offer?.status == OfferStatus.accepted && (offer!.amount > 0)) return ThreadStatus.accepted;
    if (pickup != null) return ThreadStatus.ready;
    return ThreadStatus.waiting;
  }

  Conversation copyWith({List<Message>? messages, Offer? offer, Pickup? pickup, int? unread, Review? review, bool? closedSoldOut}) => Conversation(
        id: id,
        listingId: listingId,
        receiverId: receiverId,
        providerId: providerId,
        messages: messages ?? this.messages,
        offer: offer ?? this.offer,
        pickup: pickup ?? this.pickup,
        unread: unread ?? this.unread,
        review: review ?? this.review,
        closedSoldOut: closedSoldOut ?? this.closedSoldOut,
      );
}
