import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../models/conversation.dart';
import '../models/enums.dart';
import '../models/listing.dart';
import '../models/person.dart';
import '../models/reward.dart';
import '../services/formatters.dart';

/// Id of the signed-in (mock) user. Also the provider id of listings the user publishes.
const meId = 'me';

/// Everything the MVP needs in place of a backend. Loaded from assets/mock/*.json at startup.
class MockData {
  const MockData({required this.user, required this.people, required this.listings, required this.conversations, required this.rewards});

  final AppUser user;
  final Map<String, Person> people;
  final List<Listing> listings;
  final List<Conversation> conversations;
  final List<Reward> rewards;

  static Future<MockData> load(AssetBundle bundle, {DateTime? now}) async {
    Future<dynamic> read(String name) async => json.decode(await bundle.loadString('assets/mock/$name.json'));
    return MockData.fromJson(
      user: await read('user') as Map<String, dynamic>,
      people: await read('people') as List<dynamic>,
      listings: await read('listings') as List<dynamic>,
      conversations: await read('conversations') as List<dynamic>,
      rewards: await read('rewards') as List<dynamic>,
      now: now ?? DateTime.now(),
    );
  }

  /// All times in the mock files are relative to [now], so the data never goes stale.
  factory MockData.fromJson({
    required Map<String, dynamic> user,
    required List<dynamic> people,
    required List<dynamic> listings,
    required List<dynamic> conversations,
    required List<dynamic> rewards,
    required DateTime now,
  }) {
    final peopleMap = {for (final p in people) (p as Map<String, dynamic>)['id'] as String: Person.fromJson(p)};
    final listingList = [
      for (final l in listings.cast<Map<String, dynamic>>()) Listing.fromJson(l, peopleMap[l['providerId']]!, now, ownerId: meId),
    ];
    final byId = {for (final l in listingList) l.id: l};

    Conversation conv(Map<String, dynamic> c) {
      final listing = byId[c['listingId']]!;
      final id = c['id'] as String;
      Message msg(int i, Map<String, dynamic> m) => Message(
            id: '${id}_m$i',
            senderId: m['from'] as String,
            type: MessageType.values.firstWhere((t) => t.name == m['type']),
            body: (m['text'] as String).replaceAll('{pickupBy}', formatTime(listing.pickupBy)),
            at: now.subtract(Duration(minutes: (m['minutesAgo'] as num).toInt())),
            amount: (m['amount'] as num?)?.toInt(),
          );
      final o = c['offer'] as Map<String, dynamic>?;
      final p = c['pickup'] as Map<String, dynamic>?;
      return Conversation(
        id: id,
        listingId: listing.id,
        receiverId: c['receiverId'] as String,
        providerId: c['providerId'] as String,
        unread: (c['unread'] as num?)?.toInt() ?? 0,
        closedSoldOut: (c['closedSoldOut'] ?? false) as bool,
        messages: [for (final e in (c['messages'] as List<dynamic>).cast<Map<String, dynamic>>().indexed) msg(e.$1, e.$2)],
        offer: o == null
            ? null
            : Offer(
                id: 'o_$id',
                listingId: listing.id,
                receiverId: c['receiverId'] as String,
                amount: (o['amount'] as num).toInt(),
                portions: (o['portions'] as num?)?.toInt() ?? 1,
                status: OfferStatus.values.firstWhere((s) => s.name == o['status']),
              ),
        pickup: p == null ? null : Pickup(id: 'pk_$id', code: p['code'] as String, status: PickupStatus.values.firstWhere((s) => s.name == p['status'])),
      );
    }

    return MockData(
      user: AppUser.fromJson(user),
      people: peopleMap,
      listings: listingList,
      conversations: [for (final c in conversations.cast<Map<String, dynamic>>()) conv(c)],
      rewards: [for (final r in rewards.cast<Map<String, dynamic>>()) Reward.fromJson(r)],
    );
  }
}
