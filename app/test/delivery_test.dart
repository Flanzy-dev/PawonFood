import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pawonfood/core/data/chat_repository.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/providers.dart';
import 'package:pawonfood/core/data/session_repository.dart';
import 'package:pawonfood/core/mock/mock_data.dart';
import 'package:pawonfood/core/models/conversation.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/services/formatters.dart';
import 'package:pawonfood/core/services/geo.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/core/widgets/app_button.dart';
import 'package:pawonfood/core/widgets/app_chip.dart';
import 'package:pawonfood/core/widgets/brand_icons.dart';
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

    test('"Tawar ongkir": a lower fee goes into the bubble and, once accepted, into the total', () async {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.openForListing('l_campur'); // Rp8.000, ongkir Rp3.000
      // Only the ongkir is haggled, so the food may stay at the full price.
      expect(chat.sendOffer(id, 8000, delivery: melati, deliveryFee: 2000), isNull);
      expect(c.read(conversationProvider(id))!.messages.last.body, 'Tawaran Rp8.000 · 1 porsi · diantar · ongkir Rp2.000');
      await pumpEventQueue();
      final conv = c.read(conversationProvider(id))!;
      expect(conv.offer!.status, OfferStatus.accepted, reason: 'half the fee or more is fine');
      final r = c.read(reservationProvider(id))!;
      expect((r.amount, r.deliveryFee, r.total), (8000, 2000, 10000));
    });

    test('"Tawar ongkir" is checked: never above the provider\'s fee, and the full price needs a lower fee', () {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.openForListing('l_campur');
      expect(chat.sendOffer(id, 7000, delivery: melati, deliveryFee: 5000), 'Ongkir tawaran harus Rp0 sampai Rp3.000.');
      expect(chat.sendOffer(id, 8000, delivery: melati, deliveryFee: 3000), 'Tawaran harus di bawah Rp8.000. Mau harga penuh? Pakai tombol Ambil.');
      expect(chat.sendOffer(id, 9000, delivery: melati, deliveryFee: 0), 'Tawaran paling tinggi Rp8.000.');
      expect(c.read(conversationProvider(id))!.messages, isEmpty);
    });

    test('an ongkir that is too low gets a counter for the fee, and a low price a counter for both', () async {
      final c = signedIn();
      final chat = c.read(chatProvider.notifier);
      final id = chat.openForListing('l_campur');
      expect(chat.sendOffer(id, 7000, delivery: melati, deliveryFee: 1000), isNull);
      await pumpEventQueue();
      var conv = c.read(conversationProvider(id))!;
      expect(conv.offer!.status, OfferStatus.rejected);
      expect((conv.offer!.counter, conv.offer!.counterFee), (7000, 2000), reason: 'the price was fine and stays');
      expect(conv.messages.last.body, 'Maaf, ongkirnya paling rendah Rp2.000 ya.');

      expect(chat.sendOffer(id, 1000, delivery: melati, deliveryFee: 0), isNull);
      await pumpEventQueue();
      conv = c.read(conversationProvider(id))!;
      expect((conv.offer!.counter, conv.offer!.counterFee), (5000, 2000));
      expect(conv.messages.last.body, 'Maaf, paling rendah Rp5.000, ongkirnya Rp2.000 ya.');
      expect(conv.pickup, isNull);
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

    testWidgets('"Tulis tawaranmu" offers a lower ongkir; the counter comes back as one tap', (tester) async {
      await openDetail(tester, 'l_campur'); // Rp8.000, ongkir Rp3.000
      await tester.ensureVisible(find.text('Minta diantar'));
      await tester.tap(find.text('Minta diantar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tulis sendiri'));
      await tester.tap(find.text('Tulis sendiri'));
      await tester.pumpAndSettle();
      expect(find.text('Tawar ongkir'), findsOneWidget);
      for (final chip in ['Rp3.000', 'Rp2.000', 'Rp1.000', 'Gratis']) {
        expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(chip)), findsOneWidget);
      }
      await tester.tap(find.text('Rp1.000'));
      final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(fields.at(0), '7000');
      await tester.pumpAndSettle();
      expect(find.text('+ ongkir Rp1.000'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(InkWell, 'Kirim tawaran · Rp7.000'));
      await tester.tap(find.widgetWithText(InkWell, 'Kirim tawaran · Rp7.000'));
      await tester.pumpAndSettle();

      expect(find.text('1 porsi · diantar · ongkir Rp1.000'), findsOneWidget);
      expect(find.text('Maaf, ongkirnya paling rendah Rp2.000 ya.'), findsOneWidget);
      expect(find.textContaining('bisa di harga Rp7.000 per porsi, ongkir Rp2.000. Kamu bisa menawar lagi.'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, 'Tawar Rp7.000 · ongkir Rp2.000'));
      await tester.pumpAndSettle();
      expect(find.text('Tawaran Rp7.000 diterima'), findsOneWidget);
    });

    /// A signed-in container with a thread for [listingId], shown in the chat screen.
    Future<(ProviderContainer, String)> openChat(WidgetTester tester, String listingId, {void Function(ChatNotifier chat, String id)? setUp}) async {
      usePhoneScreen(tester);
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).login('rafi@email.com');
      final chat = container.read(chatProvider.notifier);
      final id = chat.openForListing(listingId);
      setUp?.call(chat, id);
      final router = GoRouter(initialLocation: '/chat/$id', routes: [GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!))]);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
      await tester.pumpAndSettle();
      return (container, id);
    }

    testWidgets('the "+" opens "Tawar harga makanan" and "Tawar ongkir"; the ongkir sheet sends only the fee', (tester) async {
      final (container, id) = await openChat(tester, 'l_campur'); // Rp8.000, ongkir Rp3.000
      expect(find.byType(FluentSendIcon), findsOneWidget, reason: 'the send button is the Fluent paper plane');
      expect(find.bySemanticsLabel('Kirim pesan'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pumpAndSettle();
      expect(find.text('Tawar harga makanan'), findsOneWidget);
      expect(find.text('Harga Rp8.000 per porsi'), findsOneWidget);
      expect(find.textContaining('Ongkir Rp3.000 ·'), findsOneWidget);

      await tester.tap(find.text('Tawar ongkir'));
      await tester.pumpAndSettle();
      for (final chip in ['Rp3.000', 'Rp2.000', 'Rp1.000', 'Gratis']) {
        expect(find.widgetWithText(AppChip, chip), findsOneWidget);
      }
      expect(find.text('Harga makanan tetap Rp8.000 per porsi'), findsOneWidget);
      expect(find.text('Kirim tawaran ongkir · Rp2.000'), findsOneWidget, reason: 'starts one step below the provider\'s fee');

      await tester.tap(find.widgetWithText(AppChip, 'Rp3.000'));
      await tester.pumpAndSettle();
      expect(tester.widget<InkWell>(find.widgetWithText(InkWell, 'Kirim tawaran ongkir · Rp3.000')).onTap, isNull, reason: 'the provider\'s own fee is no offer');
      await tester.tap(find.widgetWithText(AppChip, 'Rp2.000'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Kirim tawaran ongkir · Rp2.000'));
      await tester.pumpAndSettle();

      final conv = container.read(conversationProvider(id))!;
      expect((conv.offer!.amount, conv.offer!.deliveryFee), (8000, 2000), reason: 'the food stays at the listed price');
      expect(conv.status, ThreadStatus.delivering);
      expect(find.text('Ongkir Rp2.000 disetujui'), findsOneWidget);
      expect(find.byIcon(LucideIcons.plus), findsNothing, reason: 'reserved: nothing left to haggle');
    });

    testWidgets('while the provider has not answered: "Batalkan tawaran" is there, the "+" is not, and cancelling brings it back', (tester) async {
      usePhoneScreen(tester);
      final container = ProviderContainer(overrides: [...testOverrides(), simulatedOfferDelayProvider.overrideWithValue(const Duration(seconds: 30))]);
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).login('rafi@email.com');
      final chat = container.read(chatProvider.notifier);
      final id = chat.openForListing('l_campur');
      chat.sendOffer(id, 5000);
      final router = GoRouter(initialLocation: '/chat/$id', routes: [GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!))]);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Menunggu jawaban'), findsOneWidget);
      expect(find.byIcon(LucideIcons.plus), findsNothing, reason: 'one offer at a time: cancel it first');
      await tester.tap(find.text('Batalkan tawaran'));
      await tester.pumpAndSettle();
      expect(find.text('Batalkan tawaranmu?'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Batalkan tawaran'));
      await tester.pumpAndSettle();

      expect(container.read(conversationProvider(id))!.offer!.status, OfferStatus.cancelled);
      expect(find.text('Tawaran dibatalkan'), findsOneWidget);
      expect(find.byIcon(LucideIcons.plus), findsOneWidget);
      // The provider's answer was still on its way: it arrives, finds the offer cancelled and does nothing.
      await tester.pump(const Duration(seconds: 31));
      expect(container.read(conversationProvider(id))!.offer!.status, OfferStatus.cancelled);
      expect(container.read(conversationProvider(id))!.pickup, isNull);
    });

    testWidgets('"Tawar ongkir" is off, with the reason, when the provider does not deliver', (tester) async {
      await openChat(tester, 'l_ayam2'); // pickup only
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pumpAndSettle();
      expect(find.text('Penyedia belum membuka opsi antar.'), findsOneWidget);
      await tester.tap(find.text('Tawar ongkir'));
      await tester.pumpAndSettle();
      expect(find.text('Kirim tawaran ongkir'), findsNothing, reason: 'the sheet did not open');
      await tester.tap(find.text('Tawar harga makanan'));
      await tester.pumpAndSettle();
      expect(find.text('Tulis tawaranmu'), findsOneWidget);
    });

    testWidgets('after a counter the ongkir sheet starts at the provider\'s ongkir and the food at its counter price', (tester) async {
      final (container, id) = await openChat(tester, 'l_campur', setUp: (chat, id) => chat.sendOffer(id, 7000, delivery: melati, deliveryFee: 1000));
      expect(find.text('Maaf, ongkirnya paling rendah Rp2.000 ya.'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tawar ongkir'));
      await tester.pumpAndSettle();
      expect(find.text('Harga makanan tetap Rp7.000 per porsi'), findsOneWidget);
      expect(find.text('Kirim tawaran ongkir · Rp2.000'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, 'Kirim tawaran ongkir · Rp2.000'));
      await tester.pumpAndSettle();
      expect(container.read(conversationProvider(id))!.offer!.status, OfferStatus.accepted);
      expect(find.text('Tawaran Rp7.000 diterima'), findsOneWidget);
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
