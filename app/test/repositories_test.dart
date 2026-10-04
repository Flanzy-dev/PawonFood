import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/core/data/chat_repository.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/session_repository.dart';
import 'package:pawonfood/core/models/conversation.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/services/geo.dart';

import 'support.dart';

ProviderContainer signedIn() {
  final c = makeContainer();
  c.read(sessionProvider.notifier).login('rafi@email.com');
  return c;
}

void main() {
  group('session', () {
    test('login restores the demo persona, register starts at zero', () {
      final c = makeContainer();
      expect(c.read(sessionProvider), isNull);
      c.read(sessionProvider.notifier).login('rafi@email.com');
      expect(c.read(sessionProvider)!.points, 150);
      expect(c.read(sessionProvider)!.tier, Tier.sobatPawon);
      c.read(sessionProvider.notifier).register(name: 'Dina', emailOrPhone: 'dina@email.com', roles: {UserRole.receiver});
      expect(c.read(sessionProvider)!.points, 0);
      expect(c.read(sessionProvider)!.roleLabel, 'Penerima');
    });
  });

  group('feed', () {
    test('Pogung shows the most urgent listing first and hides sold-out ones', () {
      final c = signedIn();
      final feed = c.read(feedProvider);
      expect(feed.first.listing.id, 'l_ayam');
      expect(feed.any((i) => i.listing.isSoldOut), isFalse);
      expect(feed.every((i) => i.distance <= 1000), isTrue);
    });

    test('Condongcatur is empty at 1 km and has a listing at 2 km (empty-state demo)', () {
      final c = signedIn();
      c.read(locationProvider.notifier).select(locations.last);
      expect(c.read(feedProvider), isEmpty);
      c.read(radiusMetersProvider.notifier).state = 2000;
      c.read(feedFiltersProvider.notifier).state = {};
      expect(c.read(feedProvider).map((i) => i.listing.id), contains('l_lodeh2'));
    });

    test('filters: free, raw ingredients and search', () {
      final c = signedIn();
      c.read(feedFiltersProvider.notifier).state = {FeedFilter.free};
      expect(c.read(feedProvider).every((i) => i.listing.isFree), isTrue);
      c.read(feedFiltersProvider.notifier).state = {FeedFilter.raw};
      expect(c.read(feedProvider).every((i) => i.listing.category == FoodCategory.bahanMentah), isTrue);
      c.read(feedFiltersProvider.notifier).state = {};
      c.read(searchQueryProvider.notifier).state = 'lodeh';
      expect(c.read(feedProvider).map((i) => i.listing.name), everyElement(contains('Lodeh')));
    });
  });

  group('claim, negotiate and pick up', () {
    test('seeded threads have the right status labels', () {
      final c = signedIn();
      final byId = {for (final t in c.read(chatProvider)) t.id: t.status};
      expect(byId['c1'], ThreadStatus.accepted);
      expect(byId['c2'], ThreadStatus.ready);
      expect(byId['c3'], ThreadStatus.soldOut);
      expect(byId['c4'], ThreadStatus.waiting);
      expect(c.read(receivedThreadsProvider).length, 3);
      expect(c.read(sharedThreadsProvider).length, 1);
    });

    test('claim creates an accepted offer and a PWN code; pickup consumes a portion and counts impact', () async {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.claim('l_ayam2');
      final conv = c.read(conversationProvider(id))!;
      expect(conv.offer!.status, OfferStatus.accepted);
      expect(conv.offer!.amount, 7000);
      expect(conv.pickup!.code, matches(RegExp(r'^PWN-\d{4}$')));
      expect(c.read(listingByIdProvider('l_ayam2'))!.portionsLeft, 3);

      chat.markPickedUp(id);
      expect(c.read(conversationProvider(id))!.pickup!.status, PickupStatus.pickedUp);
      expect(c.read(conversationProvider(id))!.status, ThreadStatus.done);
      expect(c.read(listingByIdProvider('l_ayam2'))!.portionsLeft, 2);
      expect(c.read(sessionProvider)!.portionsSaved, 8);
      await pumpEventQueue();
    });

    test('the last portion makes a listing "habis" and removes it from the feed', () {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final listings = c.read(listingsProvider.notifier);
      listings.consume('l_ayam', 1);
      final id = chat.claim('l_ayam');
      chat.markPickedUp(id);
      expect(c.read(listingByIdProvider('l_ayam'))!.status, ListingStatus.habis);
      expect(c.read(feedProvider).any((i) => i.listing.id == 'l_ayam'), isFalse);
    });

    test('an offer of at least half the price is accepted by the simulated provider', () async {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.openForListing('l_ayam2');
      expect(chat.sendOffer(id, 3500), isNull);
      await pumpEventQueue();
      final conv = c.read(conversationProvider(id))!;
      expect(conv.offer!.status, OfferStatus.accepted);
      expect(conv.pickup, isNotNull);
      expect(conv.status, ThreadStatus.accepted);
      expect(conv.messages.last.type, MessageType.system);
    });

    test('a low offer gets a counter and no pickup code', () async {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.openForListing('l_campur'); // Rp8.000, negotiable
      expect(chat.sendOffer(id, 1000), isNull);
      await pumpEventQueue();
      final conv = c.read(conversationProvider(id))!;
      expect(conv.offer!.status, OfferStatus.rejected);
      expect(conv.pickup, isNull);
      expect(conv.messages.last.body, 'Maaf, paling rendah Rp5.000 ya.');
    });

    test('invalid offers are refused with a message', () {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.openForListing('l_ayam');
      expect(chat.sendOffer(id, 6000), 'Tawaran tidak boleh melebihi harga');
      expect(chat.sendOffer(id, 0), 'Masukkan nominal tawaran');
    });

    test('provider side: accept an offer, hand over the food and earn points', () {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      chat.acceptOffer('c4');
      final conv = c.read(conversationProvider('c4'))!;
      expect(conv.pickup!.code, matches(RegExp(r'^PWN-\d{4}$')));
      chat.markPickedUp('c4');
      final user = c.read(sessionProvider)!;
      expect(user.points, 160);
      expect(user.portionsShared, 13);
      expect(c.read(listingByIdProvider('l_own'))!.portionsLeft, 3);
    });

    test('rejecting an offer closes it without a code', () {
      final c = signedIn();
      c.read(chatProvider.notifier).rejectOffer('c4');
      final conv = c.read(conversationProvider('c4'))!;
      expect(conv.offer!.status, OfferStatus.rejected);
      expect(conv.pickup, isNull);
    });

    test('opening a chat twice reuses the thread; unread clears when read', () {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      expect(chat.openForListing('l_ayam'), 'c1');
      expect(c.read(conversationProvider('c1'))!.unread, 1);
      chat.markRead('c1');
      expect(c.read(conversationProvider('c1'))!.unread, 0);
    });

    test('review is stored on the thread', () {
      final c = signedIn();
      c.read(chatProvider.notifier).submitReview('c1', const Review(pickupId: 'pk_c1', rating: 5, tags: ['Masih hangat']));
      expect(c.read(conversationProvider('c1'))!.review!.rating, 5);
    });
  });

  group('publishing a listing', () {
    PublishDraft draft({String name = 'Ayam goreng', int portions = 2, int price = 5000, Duration? pickupIn}) => PublishDraft(
          name: name,
          category: FoodCategory.makananMatang,
          portions: portions,
          price: price,
          negotiable: true,
          pickupBy: fixedNow.add(pickupIn ?? const Duration(hours: 2)),
          pickupPoint: 'Kos Melati, Pogung',
          aiConfidence: 0.86,
        );

    test('rejects an empty name, bad portions, negative price and a past deadline', () {
      final notifier = signedIn().read(listingsProvider.notifier);
      expect(notifier.publish(draft(name: '  ')).error, 'Nama makanan wajib diisi');
      expect(notifier.publish(draft(portions: 0)).error, 'Minimal 1 porsi');
      expect(notifier.publish(draft(price: -1)).error, 'Harga tidak boleh negatif');
      expect(notifier.publish(draft(pickupIn: const Duration(minutes: -5))).error, 'Jam ambil harus di masa depan');
    });

    test('a valid listing appears first in the feed and on the map list as the user\'s own', () {
      final c = signedIn();
      final result = c.read(listingsProvider.notifier).publish(draft());
      expect(result.error, isNull);
      expect(result.listing!.isOwn, isTrue);
      expect(c.read(listingsProvider).first.id, result.listing!.id);
      expect(c.read(feedProvider).any((i) => i.listing.id == result.listing!.id), isTrue);
    });

    test('free food is allowed (price 0)', () {
      expect(signedIn().read(listingsProvider.notifier).publish(draft(price: 0)).listing!.isFree, isTrue);
    });
  });
}
