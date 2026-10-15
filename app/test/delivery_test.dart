import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawonfood/core/data/chat_repository.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/session_repository.dart';
import 'package:pawonfood/core/mock/mock_data.dart';
import 'package:pawonfood/core/models/conversation.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/services/formatters.dart';
import 'package:pawonfood/core/services/geo.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/core/widgets/food_card.dart';
import 'package:pawonfood/features/chat/chat_screen.dart';
import 'package:pawonfood/features/listing/listing_detail_screen.dart';
import 'package:pawonfood/features/pickup/route_screen.dart';

import 'accessibility_test.dart' show host, useSmallPhone;
import 'support.dart';

/// "Minta diantar" to Kos Melati (the demo's primary saved point). The fee here is ignored: it always comes from the listing.
const melati = Delivery(address: 'Kos Melati, Pogung', position: pogung, fee: 99999);

/// About 2.5 km south of the food, outside the 1 km delivery radius.
const farAway = Delivery(address: 'Jl. Kaliurang km 5', position: LatLng(-7.7800, 110.3800), fee: 0);

ProviderContainer signedIn() {
  final c = makeContainer();
  c.read(sessionProvider.notifier).login('rafi@email.com');
  return c;
}

void main() {
  group('choosing pickup or delivery', () {
    test('"Ambil" with delivery keeps the address and adds the listing\'s fee on top of the food', () async {
      final c = signedIn();
      final id = c.read(chatProvider.notifier).claim('l_nasitelur', delivery: melati);
      final conv = c.read(conversationProvider(id))!;
      expect(conv.pickup, isNotNull);
      expect(conv.offer!.delivery!.address, 'Kos Melati, Pogung');
      expect(conv.offer!.deliveryFee, 2000, reason: 'the fee is the provider\'s, never the request\'s');
      final r = c.read(reservationProvider(id))!;
      expect((r.amount, r.deliveryFee, r.total, r.payable), (4000, 2000, 6000, 6000));
      expect(conv.messages.map((m) => m.body), contains('Saya minta diantar ke Kos Melati, Pogung ya.'));
      await pumpEventQueue();
      expect(c.read(conversationProvider(id))!.messages.last.body, 'Siap, saya antar sebelum ${formatTime(c.read(listingByIdProvider('l_nasitelur'))!.pickupBy)} ya.');
    });

    test('a pickup-only listing or an address over 1 km reserves nothing and says why', () {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final noDelivery = chat.claim('l_ayam2', delivery: melati);
      expect(c.read(conversationProvider(noDelivery))!.pickup, isNull);
      expect(c.read(conversationProvider(noDelivery))!.messages.last.body, 'Penyedia belum membuka opsi antar.');
      expect(c.read(listingByIdProvider('l_ayam2'))!.portionsLeft, 3, reason: 'nothing was held');

      final tooFar = chat.claim('l_nasitelur', delivery: farAway);
      expect(c.read(conversationProvider(tooFar))!.pickup, isNull);
      expect(c.read(conversationProvider(tooFar))!.messages.last.body, 'Alamatmu lebih dari 1 km dari penyedia.');
      expect(chat.sendOffer(tooFar, 3000, delivery: farAway), 'Alamatmu lebih dari 1 km dari penyedia.');
    });

    test('an offer carries the delivery into the reservation; the bubble says "diantar" but not where', () async {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.openForListing('l_campur');
      expect(chat.sendOffer(id, 7000, delivery: melati), isNull);
      expect(c.read(conversationProvider(id))!.messages.last.body, 'Tawaran Rp7.000 · 1 porsi · diantar');
      await pumpEventQueue();
      final conv = c.read(conversationProvider(id))!;
      expect(conv.offer!.status, OfferStatus.accepted);
      expect(conv.pickup, isNotNull);
      expect(conv.offer!.deliveryFee, 3000);
      expect(conv.messages.map((m) => m.body), contains(startsWith('Boleh, saya antar sebelum')));
      expect(c.read(reservationProvider(id))!.total, 10000);
    });

    test('free food delivered for free shows as "Siap diantar" and needs no payment', () async {
      final c = signedIn();
      final id = c.read(chatProvider.notifier).claim('l_sayur2', delivery: melati);
      final conv = c.read(conversationProvider(id))!;
      expect(conv.status, ThreadStatus.delivering);
      expect(conv.status.label, 'Siap diantar');
      expect(c.read(reservationProvider(id))!.total, 0);
      await pumpEventQueue();
    });

    test('a food voucher comes off the total, and the QRIS line includes the delivery fee', () async {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.claim('l_nasitelur', delivery: melati);
      expect(chat.applyVoucher(id, 'PWN-V-3001'), isNull);
      expect(c.read(reservationProvider(id))!.discount, 3000, reason: 'capped by the food price (Rp4.000 − Rp1.000), not the total');
      expect(c.read(reservationProvider(id))!.payable, 3000);
      expect(chat.checkQrisPayment(id), isFalse);
      expect(chat.checkQrisPayment(id), isTrue);
      expect(c.read(conversationProvider(id))!.messages.last.body, 'Pembayaran Rp3.000 via QRIS berhasil.');
      await pumpEventQueue();
    });

    test('"Bisa diantar?" gets the fee, or a no for pickup-only food', () async {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final yes = chat.openForListing('l_nasitelur');
      final no = chat.openForListing('l_ayam2');
      chat.sendText(yes, 'Bisa diantar?');
      chat.sendText(no, 'Bisa diantar?');
      await pumpEventQueue();
      expect(c.read(conversationProvider(yes))!.messages.last.body, 'Bisa, ongkirnya Rp2.000. Pilih "Minta diantar" di halaman makanan ya.');
      expect(c.read(conversationProvider(no))!.messages.last.body, 'Maaf, belum bisa antar. Ambil sendiri ya.');
    });
  });

  group('the provider opens delivery', () {
    PublishDraft draft({int? deliveryFee, bool allowsPickup = true}) => PublishDraft(
          name: 'Ayam goreng',
          category: FoodCategory.makananMatang,
          portions: 2,
          price: 5000,
          negotiable: true,
          pickupBy: fixedNow.add(const Duration(hours: 2)),
          pickupPoint: 'Kos Melati, Pogung',
          deliveryFee: deliveryFee,
          allowsPickup: allowsPickup,
        );

    test('the fee is kept, pickup-only stays the default, and other fees are refused', () {
      final notifier = signedIn().read(listingsProvider.notifier);
      expect(notifier.publish(draft()).listing!.canDeliver, isFalse);
      expect(notifier.publish(draft(deliveryFee: 3000)).listing!.deliveryFee, 3000);
      expect(notifier.publish(draft(deliveryFee: 0)).listing!.canDeliver, isTrue);
      expect(notifier.publish(draft(deliveryFee: 2500)).error, 'Pilih ongkir Rp0, Rp2.000 atau Rp3.000');
    });

    test('pickup can be turned off for delivery-only food, but not together with delivery', () {
      final notifier = signedIn().read(listingsProvider.notifier);
      final only = notifier.publish(draft(deliveryFee: 2000, allowsPickup: false)).listing!;
      expect((only.allowsPickup, only.canDeliver), (false, true));
      expect(notifier.publish(draft(allowsPickup: false)).error, 'Pilih minimal satu cara serah terima.');
    });

    test('the "Bisa diantar" filter keeps only listings that can be delivered', () {
      final c = signedIn();
      c.read(feedFiltersProvider.notifier).state = {FeedFilter.delivery};
      final ids = c.read(feedProvider).map((i) => i.listing.id).toSet();
      expect(ids, containsAll(['l_nasitelur', 'l_sayur2', 'l_campur']));
      expect(c.read(feedProvider).every((i) => i.listing.canDeliver), isTrue);
    });
  });

  group('delivery-only food', () {
    test('it can not be picked up: "Ambil" or an offer without a delivery reserves nothing', () async {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.claim('l_roti');
      expect(c.read(conversationProvider(id))!.pickup, isNull);
      expect(c.read(conversationProvider(id))!.messages.last.body, 'Makanan ini hanya bisa diantar.');
      expect(chat.sendOffer(id, 3000), 'Makanan ini hanya bisa diantar.');

      chat.claim('l_roti', delivery: melati);
      final r = c.read(reservationProvider(id))!;
      expect((r.amount, r.deliveryFee, r.total), (4000, 2000, 6000));
      await pumpEventQueue();
    });

    test('the seeded delivery on your own listing waits for you as "Siap diantar"', () {
      final c = signedIn();
      final r = c.read(reservationProvider('c5'))!;
      expect(r.asReceiver, isFalse);
      expect(r.delivery!.address, 'Kos Mawar, Pogung Kidul');
      expect((r.amount, r.deliveryFee, r.payable), (5000, 2000, 7000), reason: 'the fee comes from the listing');
      expect(r.pickup.payMethod, PayMethod.cash);
      expect(c.read(conversationProvider('c5'))!.status, ThreadStatus.delivering);
    });
  });

  group('screens', () {
    setUpAll(loadAppFonts);

    GoRouter router(String listingId) => GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => ListingDetailScreen(listingId: listingId)),
          GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!)),
        ]);

    Future<ProviderContainer> openDetail(WidgetTester tester, String listingId) async {
      usePhoneScreen(tester);
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).login('rafi@email.com');
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router(listingId))));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('"Cara ambil" only shows for food the provider can deliver', (tester) async {
      await openDetail(tester, 'l_ayam2');
      expect(find.text('Cara ambil'), findsNothing);
      expect(find.text('Ambil · Rp7.000'), findsOneWidget);
    });

    testWidgets('picking "Minta diantar" puts the fee in the button, and the chat card skips the walking route', (tester) async {
      final container = await openDetail(tester, 'l_nasitelur');
      expect(find.text('Cara ambil'), findsOneWidget);
      expect(find.text('Ambil · Rp4.000'), findsOneWidget);
      expect(find.text('+Rp2.000 · ke Kos Melati, Pogung'), findsOneWidget);

      await tester.ensureVisible(find.text('Minta diantar'));
      await tester.tap(find.text('Minta diantar'));
      await tester.pumpAndSettle();
      expect(find.text('Ambil · Rp6.000'), findsOneWidget);

      await tester.tap(find.text('Ambil · Rp6.000'));
      await tester.pumpAndSettle();
      final conv = container.read(chatProvider).firstWhere((c) => c.listingId == 'l_nasitelur' && c.receiverId == meId);
      expect(conv.offer!.delivery!.address, 'Kos Melati, Pogung');
      expect(find.text('Pilih cara bayar'), findsOneWidget);
      expect(find.text('Lihat rute'), findsNothing, reason: 'the provider brings the food');
    });

    testWidgets('delivery-only food: "Ambil sendiri" is off and the button already counts the fee', (tester) async {
      await openDetail(tester, 'l_roti');
      expect(find.text('Penyedia hanya mengantar'), findsOneWidget);
      expect(find.text('Antar sebelum'), findsOneWidget);
      expect(find.text('Ambil · Rp6.000'), findsOneWidget);
    });

    Future<void> openThread(WidgetTester tester, String location) async {
      usePhoneScreen(tester);
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).login('rafi@email.com');
      final router = GoRouter(initialLocation: location, routes: [
        GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!)),
        GoRoute(path: '/route/:id', builder: (_, s) => RouteScreen(conversationId: s.pathParameters['id']!)),
        GoRoute(path: '/qr/:id', builder: (_, s) => Scaffold(body: Text('qr ${s.pathParameters['id']}'))),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
      await tester.pumpAndSettle();
    }

    testWidgets('the provider\'s delivery card offers the QR and "Lihat rute antar"', (tester) async {
      await openThread(tester, '/chat/c5');
      expect(find.textContaining('Antar ke Dito di Kos Mawar, Pogung Kidul'), findsOneWidget);
      expect(find.textContaining('Terima Rp7.000 tunai di tempat'), findsOneWidget);
      expect(find.text('Buka QR ambil'), findsOneWidget);
      await tester.tap(find.text('Lihat rute antar'));
      await tester.pumpAndSettle();
      expect(find.text('Rute antar'), findsOneWidget);
    });

    testWidgets('"Rute antar": from the kitchen to the receiver, then "Buka QR ambil" on arrival', (tester) async {
      await openThread(tester, '/route/c5');
      expect(find.text('Rute antar'), findsOneWidget);
      expect(find.text('Kos Melati, Pogung'), findsOneWidget, reason: 'without GPS the trip starts at the food');
      expect(find.text('Dito, anak kos'), findsWidgets);
      expect(find.text('Kos Mawar, Pogung Kidul · alamat antar'), findsOneWidget);
      expect(find.text('Tunjukkan QR ke Dito'), findsOneWidget);
      expect(find.text('Terima Rp7.000'), findsOneWidget);
      expect(find.text('tunai saat sampai'), findsOneWidget);

      await tester.tap(find.text('Mulai antar'));
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      expect(find.text('Kamu sudah sampai'), findsWidgets);
      expect(find.textContaining('Buka QR ambil, lalu minta Dito memindainya. Terima Rp7.000 tunai.'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, 'Buka QR ambil'));
      await tester.pumpAndSettle();
      expect(find.text('qr c5'), findsOneWidget);
    });

    testWidgets('a food card that can be delivered says so to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final l = loadMockData().listings.firstWhere((l) => l.id == 'l_nasitelur');
      await tester.pumpWidget(ProviderScope(
        overrides: testOverrides(),
        child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: FoodCard(listing: l, distance: 296, onTap: () {}))),
      ));
      expect(find.bySemanticsLabel(RegExp('bisa diantar')), findsOneWidget);
      handle.dispose();
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('the delivery icon on a card and "Cara ambil" fit a 360 dp phone at ${scale}x', (tester) async {
        useSmallPhone(tester, scale);
        final l = loadMockData().listings.firstWhere((l) => l.id == 'l_nasitelur');
        await tester.pumpWidget(host(FoodCard(listing: l, distance: 502, onTap: () {})));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(ProviderScope(overrides: testOverrides(), child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router('l_nasitelur'))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Minta diantar'), findsOneWidget);

        await tester.pumpWidget(ProviderScope(overrides: testOverrides(), child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router('l_roti'))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final routes = GoRouter(initialLocation: '/route/c5', routes: [GoRoute(path: '/route/:id', builder: (_, s) => RouteScreen(conversationId: s.pathParameters['id']!))]);
        await tester.pumpWidget(ProviderScope(overrides: testOverrides(), child: MaterialApp.router(theme: AppTheme.light(), routerConfig: routes)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Mulai antar'), findsOneWidget);
      });
    }
  });
}
