import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/pickup_points_repository.dart';
import 'package:pawonfood/core/services/geo.dart';
import 'package:pawonfood/core/services/location_service.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/features/share/map_picker_screen.dart';

import 'support.dart';

/// Answers with a fixed GPS result and place names, and records which settings page was opened.
class FakeLocator implements DeviceLocator {
  FakeLocator(this.fix, {this.name, this.street});
  final LocationFix fix;
  final String? name;
  final String? street;
  var locateCalls = 0;
  String? opened;

  @override
  Future<LocationFix> locate() async {
    locateCalls++;
    return fix;
  }

  @override
  Stream<LatLng> track() => const Stream.empty();
  @override
  Future<String?> placeName(LatLng p) async => name;
  @override
  Future<String?> address(LatLng p) async => street;
  @override
  Future<void> openAppSettings() async => opened = 'app';
  @override
  Future<void> openLocationSettings() async => opened = 'location';
}

const sinduadi = LatLng(-7.7650, 110.3740); // about 750 m south-west of Pogung

void main() {
  setUpAll(loadAppFonts);

  Future<ProviderContainer> openLocationSheet(WidgetTester tester, DeviceLocator locator) async {
    usePhoneScreen(tester);
    await signIn(tester, locator: locator);
    await tester.tap(find.text('Pogung, Sleman').first);
    await tester.pumpAndSettle();
    expect(find.text('Gunakan lokasi saat ini'), findsOneWidget);
    return ProviderScope.containerOf(tester.element(find.text('Lapar? Masih ada yang hangat di dekatmu.')));
  }

  group('Beranda "Gunakan lokasi saat ini"', () {
    testWidgets('uses the GPS position and the place name, and resets the radius', (tester) async {
      final c = await openLocationSheet(tester, FakeLocator(const LocationFound(sinduadi), name: 'Sinduadi, Sleman'));
      c.read(radiusMetersProvider.notifier).state = 2000;
      await tester.tap(find.text('Gunakan lokasi saat ini'));
      await tester.pumpAndSettle();

      final loc = c.read(locationProvider);
      expect(loc.fromGps, isTrue);
      expect(loc.position, sinduadi);
      expect(loc.name, 'Sinduadi, Sleman');
      expect(c.read(lastFixProvider), sinduadi);
      expect(c.read(radiusMetersProvider), walkableRadiusMeters);
      expect(find.text('Sinduadi, Sleman'), findsOneWidget, reason: 'the header shows the GPS place');

      // The sheet marks the GPS row as the current choice.
      await tester.tap(find.text('Sinduadi, Sleman'));
      await tester.pumpAndSettle();
      expect(find.text('Sinduadi, Sleman'), findsNWidgets(2), reason: 'header + GPS row subtitle');
    });

    testWidgets('without a place name the header says "Lokasi saat ini"', (tester) async {
      final c = await openLocationSheet(tester, FakeLocator(const LocationFound(LatLng(-6.2, 106.8))));
      await tester.tap(find.text('Gunakan lokasi saat ini'));
      await tester.pumpAndSettle();
      expect(c.read(locationProvider).name, currentLocationLabel);
      expect(c.read(feedProvider), isEmpty, reason: 'no mock food in Jakarta: the empty state takes over');
    });

    for (final (issue, message, settings) in [
      (LocationIssue.denied, 'Izin lokasi ditolak. PawonFood tetap memakai daerah yang kamu pilih.', null),
      (LocationIssue.deniedForever, 'Izin lokasi diblokir. Buka setelan aplikasi untuk mengizinkan.', 'app'),
      (LocationIssue.serviceOff, 'Lokasi ponsel mati. Nyalakan lokasi, lalu coba lagi.', 'location'),
      (LocationIssue.unavailable, 'Lokasi belum ketemu. Coba lagi di tempat terbuka.', null),
    ]) {
      testWidgets('${issue.name}: explains it and keeps the chosen area', (tester) async {
        final locator = FakeLocator(LocationProblem(issue));
        final c = await openLocationSheet(tester, locator);
        await tester.tap(find.text('Gunakan lokasi saat ini'));
        await tester.pumpAndSettle();
        expect(find.text('Gunakan lokasi saat ini'), findsNothing, reason: 'the sheet closes so the snack is visible');
        expect(find.text(message), findsOneWidget);
        expect(c.read(locationProvider).name, 'Pogung, Sleman');
        expect(c.read(locationProvider).fromGps, isFalse);
        if (settings != null) {
          await tester.tap(find.text('Setelan'));
          await tester.pumpAndSettle();
          expect(locator.opened, settings);
        } else {
          expect(find.text('Setelan'), findsNothing);
        }
      });
    }
  });

  group('place names', () {
    test('a placemark gives "<kelurahan>, <kabupaten>" without the "Kabupaten" prefix', () {
      const m = gc.Placemark(subLocality: 'Sinduadi', locality: 'Mlati', subAdministrativeArea: 'Kabupaten Sleman');
      expect(placeNameFrom(m, sinduadi), 'Sinduadi, Sleman');
      expect(placeNameFrom(const gc.Placemark(locality: 'Yogyakarta', subAdministrativeArea: 'Kota Yogyakarta'), sinduadi), 'Yogyakarta');
    });

    test('without a placemark: the nearest demo area within 1.5 km, else null', () {
      expect(placeNameFrom(null, const LatLng(-7.7600, 110.3800)), 'Pogung, Sleman');
      expect(placeNameFrom(const gc.Placemark(), const LatLng(-7.7600, 110.3800)), 'Pogung, Sleman');
      expect(placeNameFrom(null, const LatLng(-6.2, 106.8)), isNull);
    });
  });

  group('pickup map (C15d)', () {
    Future<PickupPoint? Function()> openPicker(WidgetTester tester, DeviceLocator locator) async {
      usePhoneScreen(tester);
      PickupPoint? picked;
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () async => picked = await context.push<PickupPoint>('/pick'), child: const Text('buka peta')),
            ),
          ),
        ),
        GoRoute(path: '/pick', builder: (_, _) => const MapPickerScreen()),
      ]);
      await tester.pumpWidget(ProviderScope(overrides: testOverrides(locator: locator), child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
      await tester.tap(find.text('buka peta'));
      await tester.pumpAndSettle();
      return () => picked;
    }

    testWidgets('opens at the GPS position and names the point with the geocoded address', (tester) async {
      const spot = LatLng(-7.7700, 110.3900); // far from every mock place
      final locator = FakeLocator(const LocationFound(spot), street: 'Jl. Kaliurang, Sinduadi');
      final picked = await openPicker(tester, locator);
      expect(locator.locateCalls, 1, reason: 'opening the map is the request for GPS');
      expect(find.text('Titik di peta'), findsOneWidget);
      expect(find.textContaining('± 0 m dari GPS'), findsOneWidget);

      await tester.tap(find.text('Pilih lokasi ini'));
      await tester.pumpAndSettle();
      final point = picked()!;
      expect(point.address, 'Jl. Kaliurang, Sinduadi');
      expect(point.name, 'Jl. Kaliurang, Sinduadi');
      expect(point.position.latitude, closeTo(spot.latitude, 1e-6));
      expect(point.position.longitude, closeTo(spot.longitude, 1e-6));
    });

    testWidgets('without GPS it stays on the demo point quietly; "Ke lokasi saya" reports the problem', (tester) async {
      final locator = FakeLocator(const LocationProblem(LocationIssue.denied));
      await openPicker(tester, locator);
      expect(find.text('Jl. Pogung Baru No. 14'), findsOneWidget, reason: 'demo point near Kos Melati');
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.bySemanticsLabel('Ke lokasi saya'));
      await tester.pumpAndSettle();
      expect(find.text('Izin lokasi ditolak. PawonFood tetap memakai daerah yang kamu pilih.'), findsOneWidget);
    });
  });
}
