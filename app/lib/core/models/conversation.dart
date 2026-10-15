import 'package:latlong2/latlong.dart';

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

/// "Minta diantar": where the provider brings the food, and the fee they set on the listing (all of it goes to them).
class Delivery {
  const Delivery({required this.address, required this.position, required this.fee});

  final String address;
  final LatLng position;
  final int fee;
}

class Offer {
  const Offer({required this.id, required this.listingId, required this.receiverId, required this.amount, this.portions = 1, this.status = OfferStatus.pending, this.delivery});

  final String id;
  final String listingId;
  final String receiverId;
  final int amount;
  final int portions;
  final OfferStatus status;

  /// Null for "Ambil sendiri". Picked on the detail screen before the offer or "Ambil", and fixed once reserved.
  final Delivery? delivery;

  /// What the food comes to: [amount] is per porsi. The delivery fee is on top ([deliveryFee]).
  int get total => amount * portions;
  int get deliveryFee => delivery?.fee ?? 0;

  Offer copyWith({OfferStatus? status, int? amount}) => Offer(
      id: id, listingId: listingId, receiverId: receiverId, amount: amount ?? this.amount, portions: portions, status: status ?? this.status, delivery: delivery);
}

/// The reservation behind an accepted offer or an "Ambil". There is no code to read out: the provider shows a QR
/// ([qrPayload]) and the receiver scans it before [deadline].
class Pickup {
  const Pickup({
    required this.id,
    required this.deadline,
    this.status = PickupStatus.reserved,
    this.pickedUpAt,
    this.payMethod,
    this.paidAt,
    this.statusChecks = 0,
    this.voucherCode,
    this.discount = 0,
    this.held = 0,
  });

  final String id;
  final DateTime deadline;
  final PickupStatus status;
  final DateTime? pickedUpAt;

  /// Portions taken out of the listing's "Sisa N porsi" while this reservation is open. They come back when it expires;
  /// 0 for reservations that never held stock (seeded demo threads).
  final int held;

  /// Null until the receiver picks how to pay (always null for free food).
  final PayMethod? payMethod;

  /// Set when an in-app QRIS payment went through.
  final DateTime? paidAt;

  /// How many times "Cek status pembayaran" was tapped (the mock gateway answers on the second check).
  final int statusChecks;

  /// Food voucher (`PWN-V-XXXX`) applied on Pembayaran and the rupiah it takes off. The voucher counts as used only once the
  /// payment is confirmed.
  final String? voucherCode;
  final int discount;

  bool get paid => paidAt != null;
  bool get open => status == PickupStatus.reserved;

  /// What the provider's QR encodes. One reservation, one scan.
  String get qrPayload => 'pawonfood://ambil/$id';

  Pickup copyWith({PickupStatus? status, DateTime? pickedUpAt, PayMethod? payMethod, DateTime? paidAt, int? statusChecks, int? discount, int? held}) => Pickup(
        id: id,
        deadline: deadline,
        status: status ?? this.status,
        pickedUpAt: pickedUpAt ?? this.pickedUpAt,
        payMethod: payMethod ?? this.payMethod,
        paidAt: paidAt ?? this.paidAt,
        statusChecks: statusChecks ?? this.statusChecks,
        voucherCode: voucherCode,
        discount: discount ?? this.discount,
        held: held ?? this.held,
      );

  /// Same reservation with a voucher applied, or with it removed ([code] null).
  Pickup withVoucher(String? code, int discount) => Pickup(
        id: id,
        deadline: deadline,
        status: status,
        pickedUpAt: pickedUpAt,
        payMethod: payMethod,
        paidAt: paidAt,
        statusChecks: statusChecks,
        voucherCode: code,
        discount: discount,
        held: held,
      );
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
  delivering('Siap diantar'),
  done('Selesai'),
  expired('Kedaluwarsa'),
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
    if (pickup?.status == PickupStatus.expired) return ThreadStatus.expired;
    if (closedSoldOut && pickup == null) return ThreadStatus.soldOut;
    // A delivery says so whatever the price: both sides need to know the food travels.
    if (pickup != null && offer?.delivery != null) return ThreadStatus.delivering;
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
