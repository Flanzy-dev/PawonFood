import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_data.dart';
import '../models/enums.dart';
import '../models/listing.dart';
import '../services/points.dart';
import 'chat_repository.dart';
import 'listings_repository.dart';
import 'providers.dart';

/// One finished pickup on "Riwayat" (D18b).
class HistoryEntry {
  const HistoryEntry({required this.listing, required this.counterpart, required this.at, required this.done, required this.amount, this.points});

  final Listing listing;

  /// The provider (when the user took food) or the receiver (when the user shared).
  final String counterpart;
  final DateTime at;

  /// Picked up ("Selesai"); false means the reservation expired ("Kedaluwarsa").
  final bool done;
  final int amount;
  final int? points;
}

/// Finished pickups, newest first: this session's QR scans and expiries, then older demo entries.
/// [taking] picks the "Saya mengambil" tab, otherwise "Saya berbagi".
final historyProvider = Provider.family<List<HistoryEntry>, bool>((ref, taking) {
  final now = ref.watch(clockProvider)();
  final listings = ref.watch(listingsProvider);
  final people = ref.watch(peopleProvider);
  Listing? byId(String id) => listings.where((l) => l.id == id).firstOrNull;

  final live = <HistoryEntry>[];
  for (final c in ref.watch(chatProvider)) {
    final p = c.pickup;
    if (p == null || (p.status != PickupStatus.pickedUp && p.status != PickupStatus.expired)) continue;
    if ((c.receiverId == meId) != taking) continue;
    final l = byId(c.listingId);
    if (l == null) continue;
    final amount = c.offer?.total ?? l.price;
    final done = p.status == PickupStatus.pickedUp;
    live.add(HistoryEntry(
      listing: l,
      counterpart: (taking ? people[c.providerId] : people[c.receiverId])?.name ?? '',
      at: p.pickedUpAt ?? p.deadline,
      done: done,
      amount: amount,
      points: done ? pickupPoints(portions: c.offer?.portions ?? 1, isFree: amount == 0) : null,
    ));
  }

  HistoryEntry? seed(String listingId, String who, int daysAgo, {required bool done, int? amount}) {
    final l = byId(listingId);
    if (l == null) return null;
    final paid = amount ?? l.price;
    return HistoryEntry(listing: l, counterpart: who, at: now.subtract(Duration(days: daysAgo)), done: done, amount: paid, points: done ? pickupPoints(portions: 1, isFree: paid == 0) : null);
  }

  final older = taking
      ? [
          seed('l_ayam', 'Warteg Bu Siti', 4, done: true, amount: 4000),
          seed('l_lodeh', 'Bu Kos Wulan', 6, done: true),
          seed('l_nasitelur', 'Warmindo Barokah', 8, done: false),
          seed('l_sayur', 'Dito, anak kos', 10, done: true),
        ]
      : [
          seed('l_own', 'Dina Ayu', 3, done: true),
          seed('l_own', 'Bu Retno', 9, done: true, amount: 4000),
          seed('l_own', 'Dito, anak kos', 12, done: false),
        ];
  return [...live.reversed, for (final e in older) ?e];
});
