import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/services/formatters.dart';
import 'package:pawonfood/core/services/geo.dart';
import 'package:pawonfood/core/services/pickup_times.dart';
import 'package:pawonfood/core/services/validators.dart';
import 'package:pawonfood/core/widgets/form_controls.dart';
import 'package:pawonfood/core/widgets/listing_photo.dart';
import 'package:pawonfood/core/widgets/pawon_map.dart';
import 'package:pawonfood/core/widgets/pickup_time_sheet.dart';
import 'package:pawonfood/features/map/map_pin_card.dart';
import 'package:pawonfood/features/map/map_screen.dart';
import 'package:pawonfood/features/map/radius_indicator.dart';

import 'support.dart';

/// Map pin card, radius indicator and picker, empty map (B12c-B12g) and the provider's own pickup time ("Atur jam", C15g-C15i).
void main() {
  setUpAll(loadAppFonts);

  group('pickup time window', () {
    // fixedNow is 20.00
    test('earliest is 30 minutes away, latest 6 hours, both on the 5-minute grid', () {
      expect(formatTime(pickupEarliest(fixedNow)), '20.30');
      expect(formatTime(pickupLatest(fixedNow)), '02.00');
      final odd = DateTime(2026, 10, 3, 18, 13, 20);
      expect(formatTime(pickupEarliest(odd)), '18.45');
      expect(formatTime(pickupLatest(odd)), '00.10');
    });

    test('pickupWindow explains both limits and accepts times in between', () {
      expect(Validators.pickupWindow(DateTime(2026, 10, 3, 20, 15), fixedNow), 'Terlalu cepat. Minimal 20.30 (30 menit lagi)');
      expect(Validators.pickupWindow(DateTime(2026, 10, 4, 2, 5), fixedNow), 'Terlalu lama. Maksimal 02.00 (6 jam lagi)');
      expect(Validators.pickupWindow(DateTime(2026, 10, 3, 20, 30), fixedNow), isNull);
      expect(Validators.pickupWindow(DateTime(2026, 10, 3, 22, 0), fixedNow), isNull);
      expect(Validators.pickupWindow(DateTime(2026, 10, 4, 2, 0), fixedNow), isNull);
    });

    test('an hour and minute resolve to the next time they occur', () {
      expect(nextOccurrence(fixedNow, 21, 15), DateTime(2026, 10, 3, 21, 15));
      expect(nextOccurrence(fixedNow, 19, 0), DateTime(2026, 10, 4, 19, 0));
    });
  });

  group('TimeChips "Atur jam"', () {
    testWidgets('the fourth chip opens the picker and shows the chosen time once set', (tester) async {
      var opened = 0;
      DateTime? custom;
      final times = [DateTime(2026, 10, 3, 21, 0), DateTime(2026, 10, 3, 22, 30)];
      late StateSetter set;
      DateTime? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            set = setState;
            return TimeChips(times: times, selected: selected, now: fixedNow, custom: custom, onSelected: (t) => setState(() => selected = t), onCustom: () => opened++);
          }),
        ),
      ));
      expect(find.text('Atur jam'), findsOneWidget);
      await tester.tap(find.text('Atur jam'));
      expect(opened, 1);

      set(() {
        custom = DateTime(2026, 10, 3, 21, 15);
        selected = custom;
      });
      await tester.pumpAndSettle();
      expect(find.text('Atur jam'), findsNothing);
      expect(find.text('21.15'), findsOneWidget);
      await tester.tap(find.text('21.15')); // tapping the chosen time reopens the picker
      expect(opened, 2);
    });

    testWidgets('without onCustom there is no fourth chip', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: TimeChips(times: [DateTime(2026, 10, 3, 21, 0)], selected: null, now: fixedNow, onSelected: (_) {}))));
      expect(find.text('Atur jam'), findsNothing);
    });
  });

  group('C15g/C15h time picker sheet', () {
    Future<void> open(WidgetTester tester, void Function(DateTime?) onResult) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () async => onResult(await showPickupTimeSheet(context, now: fixedNow)), child: const Text('Buka')))),
        ),
      ));
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
    }

    testWidgets('starts an hour after the earliest time and returns it', (tester) async {
      DateTime? result;
      await open(tester, (t) => result = t);
      expect(find.text('Jam ambil paling lambat'), findsOneWidget);
      expect(find.text('Antara 20.30 dan 02.00 (30 menit sampai 6 jam dari sekarang)'), findsOneWidget);
      expect(find.text('Ambil paling lambat 21.30 · 1 jam 30 mnt lagi'), findsOneWidget);
      await tester.tap(find.text('Pakai jam ini'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 3, 21, 30));
    });

    testWidgets('a time past the 6 hour limit shows the red explanation and disables the button', (tester) async {
      DateTime? result;
      await open(tester, (t) => result = t);
      await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, -200)); // hours move forward past 02.00
      await tester.pumpAndSettle();
      expect(find.textContaining('Terlalu lama. Maksimal 02.00'), findsOneWidget);
      await tester.tap(find.text('Pakai jam ini'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Jam ambil paling lambat'), findsOneWidget); // sheet still open
    });
  });

  group('PawonMap markers', () {
    // l_ayam (Rp5.000) and l_sayur (Rp3.000) are far enough apart to stay two pins at the default zoom.
    final listings = loadMockData().listings;
    final a = listings.firstWhere((l) => l.id == 'l_ayam'), b = listings.firstWhere((l) => l.id == 'l_sayur');

    Future<MapController> pump(WidgetTester tester, {String? selectedId}) async {
      final controller = MapController();
      await tester.pumpWidget(ProviderScope(
        overrides: [tilesEnabledProvider.overrideWithValue(false)],
        child: MaterialApp(home: Scaffold(body: PawonMap(controller: controller, center: pogung, listings: [a, b], selectedId: selectedId))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // markers finish their fade-in
      return controller;
    }

    testWidgets('every marker has a key, so a pin keeps its own look when others leave the screen', (tester) async {
      final controller = await pump(tester, selectedId: a.id);
      expect(find.byKey(ValueKey('selected_large_${a.id}')), findsOneWidget); // selected = its photo in a circle
      expect(find.text('Rp5.000'), findsNothing);
      expect(find.text('Rp3.000'), findsNothing); // pins are only the photo, no price
      final photoPin = find.byKey(ValueKey('photo_${b.id}')); // an unselected pin is its photo in a circle
      expect(find.descendant(of: photoPin, matching: find.byType(ListingPhoto)), findsOneWidget);
      for (final m in tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers) {
        expect(m.key, isNotNull);
      }
      expect(tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.first.key, const ValueKey('user')); // the user's dot is the bottom layer

      // Zoom in on the white pin: the selected one leaves the screen. The white pin must not take over its look.
      controller.move(b.position, 18);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(ValueKey('selected_large_${a.id}')), findsNothing); // off screen: not built at all
      expect(find.byKey(ValueKey('photo_${b.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('selected_large_${b.id}')), findsNothing); // the other pin does not take over the selected look
    });

    testWidgets('zoomed out, the selected pin joins the circle of its neighbours; zoomed in it is its photo circle again', (tester) async {
      final controller = await pump(tester, selectedId: a.id);
      controller.move(pogung, 13);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Rp5.000'), findsNothing);
      expect(find.text('Rp3.000'), findsNothing);
      expect(find.text('2'), findsOneWidget); // one circle holding both listings

      controller.move(a.position, 18);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(ValueKey('selected_large_${a.id}')), findsOneWidget);
      expect(find.text('Rp5.000'), findsNothing);
    });
  });

  group('PawonMap clustering is path independent', () {
    final listings = loadMockData().listings;

    testWidgets('after zooming in and back out the same listings are grouped as before the detour', (tester) async {
      final controller = MapController();
      await tester.pumpWidget(ProviderScope(
        overrides: [tilesEnabledProvider.overrideWithValue(false)],
        child: MaterialApp(home: Scaffold(body: PawonMap(controller: controller, center: pogung, listings: listings))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      List<String?> shape() => [for (final w in tester.widgetList<Text>(find.descendant(of: find.byType(MarkerLayer), matching: find.byType(Text)))) w.data]..sort();
      Future<void> go(double zoom) async {
        controller.move(pogung, zoom);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await go(14.3);
      final direct = shape();
      await go(17);
      for (final z in [16, 15.2, 14.7, 14.45, 14.3]) { // zoom out in steps, ending at the same zoom as before
        await go(z.toDouble());
      }
      expect(shape(), direct);
    });
  });

  group('PawonMap selected pin as a photo circle', () {
    final listings = loadMockData().listings;
    final a = listings.firstWhere((l) => l.id == 'l_ayam'), b = listings.firstWhere((l) => l.id == 'l_sayur');

    testWidgets('the selected food is its photo in a circle with no price; smaller when zoomed out; other pins stay photo circles', (tester) async {
      final controller = MapController();
      await tester.pumpWidget(ProviderScope(
        overrides: [tilesEnabledProvider.overrideWithValue(false)],
        child: MaterialApp(home: Scaffold(body: PawonMap(controller: controller, center: pogung, listings: [a, b], selectedId: a.id))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      controller.move(a.position, 17.5); // up close: the large photo circle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(ValueKey('selected_large_${a.id}')), findsOneWidget);
      expect(find.text('Rp5.000'), findsNothing, reason: 'the destination shows the food, not its price');
      expect(find.descendant(of: find.byKey(ValueKey('selected_large_${a.id}')), matching: find.byType(ListingPhoto)), findsOneWidget);

      controller.move(a.position, 15); // zoomed out, listings still apart: a smaller photo circle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(ValueKey('selected_small_${a.id}')), findsOneWidget);
      expect(find.text('Rp5.000'), findsNothing);
      expect(find.byKey(ValueKey('photo_${b.id}')), findsOneWidget);
    });

    testWidgets('a pin that was just tapped from far away shows the large circle while the camera glides in', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [tilesEnabledProvider.overrideWithValue(false)],
        child: MaterialApp(home: Scaffold(body: PawonMap(center: pogung, listings: [a, b], selectedId: a.id))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(ValueKey('selected_small_${a.id}')), findsNothing); // never seen close yet
    });
  });

  group('RadiusIndicator layout', () {
    Future<void> check(WidgetTester tester, double meters, String number, String unit) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: RadiusIndicator(meters: meters, onTap: () {})))));
      final circle = tester.getRect(find.byType(RadiusIndicator));
      final n = tester.getRect(find.text(number)), u = tester.getRect(find.text(unit));
      // A fractional line height (a px value in AppTypography) squeezes both lines to ~1 px and the glyphs overlap.
      expect(n.height, greaterThanOrEqualTo(15), reason: 'number line height');
      expect(u.height, greaterThanOrEqualTo(11), reason: 'unit line height');
      expect(u.top, greaterThanOrEqualTo(n.bottom - 1), reason: '"$unit" must sit below "$number", not on top of it');
      expect(circle.contains(n.topLeft) && circle.contains(n.bottomRight), isTrue);
      expect(circle.contains(u.topLeft) && circle.contains(u.bottomRight), isTrue);
      expect(n.center.dx, closeTo(circle.center.dx, 1.5));
      expect(u.center.dx, closeTo(circle.center.dx, 1.5));
    }

    testWidgets('"1" above "km"', (tester) => check(tester, 1000, '1', 'km'));
    testWidgets('"2" above "km"', (tester) => check(tester, 2000, '2', 'km'));
    testWidgets('"500" above "m"', (tester) => check(tester, 500, '500', 'm'));
  });

  group('Peta B12c-B12g', () {
    Future<ProviderContainer> openMap(WidgetTester tester) async {
      usePhoneScreen(tester);
      await signIn(tester);
      final container = ProviderScope.containerOf(tester.element(find.text('Peta')));
      await tester.tap(find.text('Peta'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('tapping a price pin swaps the sheet for a floating card, zooms to it and turns the pin green; the cross undoes it', (tester) async {
      final container = await openMap(tester);
      PawonMap map() => tester.widget<PawonMap>(find.byType(PawonMap));
      MapCamera camera() => tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;
      expect(find.byType(MapPinCard), findsNothing);
      expect(find.byType(RadiusIndicator), findsOneWidget);
      expect(map().selectedId, isNull); // every pin is white until one is opened
      final overview = camera().zoom;

      await tester.tap(find.descendant(of: find.byType(PawonMap), matching: find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('photo_'))).first); // a single photo pin (nearby ones are clustered)
      await tester.pumpAndSettle();
      expect(find.byType(MapPinCard), findsOneWidget);
      final id = map().selectedId;
      expect(id, isNotNull);
      final ayam = container.read(listingByIdProvider(id!))!;
      expect(find.descendant(of: find.byType(MapPinCard), matching: find.text(ayam.name)), findsOneWidget);
      expect(tester.getSize(find.byType(MapPinCard)).height, greaterThanOrEqualTo(165));
      expect(tester.getSize(find.descendant(of: find.byType(MapPinCard), matching: find.byType(ListingPhoto))).width, 104); // big photo
      expect(find.descendant(of: find.byType(MapPinCard), matching: find.textContaining('jalan kaki')), findsOneWidget);
      expect(find.byType(RadiusIndicator), findsOneWidget); // now above the card
      expect(camera().zoom, 17);
      expect(distanceMeters(camera().center, ayam.position), lessThan(130)); // zoomed in on the spot, nudged south so the pin sits above the card

      await tester.tap(find.bySemanticsLabel('Tutup kartu'));
      await tester.pumpAndSettle();
      expect(find.byType(MapPinCard), findsNothing);
      expect(find.byType(RadiusIndicator), findsOneWidget);
      expect(map().selectedId, isNull);
      expect(camera().zoom, closeTo(overview, 0.01)); // back to the overview of the radius
    });

    testWidgets('the radius indicator opens the picker; 2 km widens the map', (tester) async {
      final container = await openMap(tester);
      expect(RadiusIndicator.parts(container.read(radiusMetersProvider)), ('1', 'km'));
      final before = container.read(mapListingsProvider).length;

      await tester.tap(find.byType(RadiusIndicator));
      await tester.pumpAndSettle();
      expect(find.text('Jangkauan pencarian'), findsOneWidget);
      expect(find.text('Tampilkan makanan dalam radius ini'), findsOneWidget);
      await tester.tap(find.text('2 km'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(container.read(radiusMetersProvider), 2000);
      expect(find.text('Radius 2 km dari'), findsOneWidget);
      expect(container.read(mapListingsProvider).length, greaterThanOrEqualTo(before));
      expect(RadiusIndicator.parts(2000), ('2', 'km'));
      expect(RadiusIndicator.parts(500), ('500', 'm'));
    });

    testWidgets('no food in the radius: empty copy, no "Perluas radius" button', (tester) async {
      final container = await openMap(tester);
      container.read(locationProvider.notifier).select(locations[2]); // Condongcatur: nothing within 1 km
      await tester.pumpAndSettle();
      expect(find.text('Belum ada makanan di radius 1 km'), findsOneWidget);
      expect(find.text('Coba perluas radius, atau jadilah yang pertama berbagi di Condongcatur.'), findsOneWidget);
      expect(find.text('Perluas radius ke 2 km'), findsNothing);
      expect(find.byType(RadiusIndicator), findsOneWidget);
    });
  });
}
