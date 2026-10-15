import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:pawonfood/core/data/chat_repository.dart';
import 'package:pawonfood/core/services/formatters.dart';
import 'package:pawonfood/core/services/location_service.dart';
import 'package:pawonfood/core/services/route_service.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/features/pickup/route_screen.dart';

import 'support.dart';

/// A real FOSSGIS foot-router answer (Jl. Pogung Baru → Warteg Bu Siti, 2026-10-15), trimmed to the fields we read.
final osrmSample = File('test/fixtures/osrm_foot_pogung.json').readAsStringSync();

class StaticPlanner implements RoutePlanner {
  StaticPlanner(this.route);
  final WalkRoute? route;

  @override
  Future<WalkRoute?> walk(LatLng from, LatLng to) async => route;
}

/// A position fix, plus a stream the test drives while "walking".
class TrackingLocator implements DeviceLocator {
  TrackingLocator(this.start);
  final LatLng start;
  final positions = StreamController<LatLng>.broadcast();

  @override
  Future<LocationFix> locate() async => LocationFound(start);
  @override
  Stream<LatLng> track() => positions.stream;
  @override
  Future<String?> placeName(LatLng p) async => null;
  @override
  Future<String?> address(LatLng p) async => null;
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

void main() {
  setUpAll(loadAppFonts);

  group('OSRM foot route', () {
    final route = parseOsrmRoute(jsonDecode(osrmSample));

    test('reads the path, distance and Indonesian turn instructions', () {
      expect(route.fromStreets, isTrue);
      expect(route.meters, 1222.1);
      expect(route.path.length, greaterThan(10));
      final texts = route.steps.map((s) => s.instruction).toList();
      expect(texts.first, 'Mulai jalan');
      expect(texts, contains('Belok kiri ke Jalan Kaliurang'));
      expect(texts, contains('Belok kanan ke Jalan Pandega Siwi'));
      expect(texts.last, 'Sampai di titik ambil');
      expect(texts.any((t) => t.contains('turn')), isFalse, reason: 'no English text from the router');
      for (var i = 1; i < route.steps.length; i++) {
        expect(route.steps[i].startsAt, greaterThanOrEqualTo(route.steps[i - 1].startsAt - 1), reason: 'steps follow the path');
      }
      expect(route.steps.last.startsAt, closeTo(pathLength(route.path), 5));
    });

    test('instruction wording', () {
      expect(instructionFor('turn', 'slight right', ''), 'Agak ke kanan');
      expect(instructionFor('turn', 'sharp left', 'Gang Mawar'), 'Belok tajam ke kiri ke Gang Mawar');
      expect(instructionFor('roundabout', 'right', ''), 'Masuk bundaran');
      expect(instructionFor('new name', 'straight', 'Jalan Pogung Raya'), 'Lurus ke Jalan Pogung Raya');
      expect(instructionFor('depart', 'right', 'Jalan Pogung Baru'), 'Mulai jalan di Jalan Pogung Baru');
      expect(instructionFor('notification', null, ''), 'Lanjutkan');
    });

    test('the planner asks the foot router with lng,lat order and a User-Agent', () async {
      late http.Request seen;
      final planner = OsrmFootPlanner(client: MockClient((req) async {
        seen = req;
        return http.Response(osrmSample, 200);
      }));
      final r = await planner.walk(const LatLng(-7.7597, 110.3799), const LatLng(-7.7576, 110.3809));
      expect(r, isNotNull);
      expect(seen.url.host, 'routing.openstreetmap.de');
      expect(seen.url.path, '/routed-foot/route/v1/foot/110.3799,-7.7597;110.3809,-7.7576');
      expect(seen.url.queryParameters['steps'], 'true');
      expect(seen.headers['User-Agent'], startsWith('PawonFood'));
      expect(r!.path.first, const LatLng(-7.7597, 110.3799), reason: 'the line starts on the real position, not the snapped road point');
      expect(r.path.last, const LatLng(-7.7576, 110.3809), reason: 'and ends on the pickup point');
    });

    test('withEnds joins the line to the real start and destination, and the steps move with it', () {
      const from = LatLng(-7.7600, 110.3796), to = LatLng(-7.7576, 110.3809); // ~33 m and ~26 m off the snapped ends
      const d = Distance();
      final head = d(from, route.path.first), tail = d(route.path.last, to);
      expect(head, greaterThan(20));
      expect(tail, greaterThan(20));

      final r = withEnds(route, from, to);
      expect(r.path.first, from);
      expect(r.path.last, to);
      expect(r.path.length, route.path.length + 2);
      expect(r.meters, closeTo(route.meters + head + tail, 0.01));
      expect(r.fromStreets, isTrue);
      expect(r.steps.length, route.steps.length);
      expect(r.steps.first.startsAt, 0);
      expect(r.steps[1].startsAt, closeTo(route.steps[1].startsAt + head, 0.01));
      expect(r.steps.last.startsAt, closeTo(pathLength(r.path), 0.01));
      for (var i = 1; i < r.steps.length; i++) {
        expect(r.steps[i].startsAt, greaterThanOrEqualTo(r.steps[i - 1].startsAt - 1), reason: 'steps still follow the path');
      }
      expect(withEnds(route, route.path.first, route.path.last), same(route), reason: 'nothing to join when the ends already match');
    });

    test('any failure gives no route, never a made-up one', () async {
      Future<WalkRoute?> run(MockClientHandler h, {Duration timeout = const Duration(seconds: 5)}) =>
          OsrmFootPlanner(client: MockClient(h), timeout: timeout).walk(const LatLng(-7.7597, 110.3799), const LatLng(-7.7576, 110.3809));
      expect(await run((_) async => http.Response('busy', 503)), isNull);
      expect(await run((_) async => http.Response('{"code":"NoRoute","routes":[]}', 200)), isNull);
      expect(await run((_) async => http.Response('{"code":"Ok","routes":[{"distance":"far"}]}', 200)), isNull);
      expect(await run((_) async => http.Response('<html>', 200)), isNull);
      expect(await run((_) async => throw http.ClientException('offline')), isNull);
      expect(await run((_) => Completer<http.Response>().future, timeout: const Duration(milliseconds: 10)), isNull);
    });
  });

  group('geometry', () {
    const a = LatLng(-7.7600, 110.3790), b = LatLng(-7.7570, 110.3820);
    final est = estimatedRoute(a, b);

    test('progressAlong projects onto the path', () {
      final path = est.path;
      expect(progressAlong(path, a), closeTo(0, 1e-6));
      expect(progressAlong(path, b), closeTo(1, 1e-6));
      final corner = const Distance()(path[0], path[1]) / pathLength(path);
      expect(progressAlong(path, path[1]), closeTo(corner, 0.01));
      final mid = pointAlong(path, 0.5);
      final beside = LatLng(mid.latitude, mid.longitude + 0.0002); // ~20 m off the path
      expect(progressAlong(path, beside), closeTo(0.5, 0.03));
    });

    test('the estimate names no streets', () {
      expect(est.fromStreets, isFalse);
      expect(est.steps.first.instruction, 'Mulai jalan');
      expect(est.steps.last.instruction, 'Sampai di titik ambil');
      expect(est.steps.any((s) => s.instruction.contains(' ke ')), isFalse);
    });
  });

  group('route screen (B8b-B8d)', () {
    Future<void> openRoute(WidgetTester tester, {DeviceLocator locator = const NoGpsLocator(), RoutePlanner planner = const NoRoutePlanner()}) async {
      usePhoneScreen(tester);
      final router = GoRouter(initialLocation: '/route/c1', routes: [
        GoRoute(path: '/route/:id', builder: (_, s) => RouteScreen(conversationId: s.pathParameters['id']!)),
        GoRoute(path: '/chat/:id', builder: (_, _) => const Scaffold(body: Text('chat'))),
        GoRoute(path: '/scan/:id', builder: (_, _) => const Scaffold(body: Text('scan'))),
      ]);
      await tester.pumpWidget(ProviderScope(overrides: testOverrides(locator: locator, planner: planner), child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
      await tester.pumpAndSettle();
    }

    testWidgets('with GPS: the street route from "Lokasi kamu saat ini", then live tracking to arrival', (tester) async {
      final route = parseOsrmRoute(jsonDecode(osrmSample));
      final locator = TrackingLocator(route.path.first);
      await openRoute(tester, locator: locator, planner: StaticPlanner(route));
      expect(find.text('Lokasi kamu saat ini'), findsOneWidget);
      expect(find.text('1,2 km'), findsOneWidget);
      expect(find.textContaining('Rute perkiraan'), findsNothing);

      await tester.tap(find.text('Mulai jalan'));
      await tester.pumpAndSettle();
      expect(locator.positions.hasListener, isTrue);
      expect(find.text('Belok kiri ke Jalan Kaliurang'), findsOneWidget, reason: 'first real turn');

      final mid = pointAlong(route.path, 0.5);
      locator.positions.add(mid);
      await tester.pumpAndSettle();
      final left = route.meters * (1 - progressAlong(route.path, mid));
      expect(find.text('Sisa ${formatDistance(left)} · ± ${walkMinutes(left)} mnt'), findsOneWidget);

      // l_ayam is the reserved listing of c1: standing within 30 m of it arrives.
      final container = ProviderScope.containerOf(tester.element(find.byType(RouteScreen)));
      final dest = container.read(reservationProvider('c1'))!.listing.position;
      locator.positions.add(LatLng(dest.latitude + 0.0001, dest.longitude));
      await tester.pumpAndSettle();
      expect(find.text('Kamu sudah sampai'), findsWidgets);
      expect(locator.positions.hasListener, isFalse, reason: 'tracking stops on arrival');
    });

    testWidgets('without GPS or a street route: the estimate, and an animated walk', (tester) async {
      await openRoute(tester);
      expect(find.text('Lokasi kamu · Pogung, Sleman'), findsOneWidget);
      expect(find.text('Rute perkiraan · jalan belum termuat'), findsOneWidget);
      await tester.tap(find.text('Mulai jalan'));
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      expect(find.text('Kamu sudah sampai'), findsWidgets);
    });

    testWidgets('the destination pin\'s tip sits on its point (the marker\'s bottom edge)', (tester) async {
      await openRoute(tester);
      final pin = find.byWidgetPredicate((w) => w is SvgPicture && w.semanticsLabel == 'Titik ambil');
      expect(pin, findsOneWidget);
      final marker = find.ancestor(of: pin, matching: find.byWidgetPredicate((w) => w is Column && w.mainAxisAlignment == MainAxisAlignment.end));
      expect(marker, findsOneWidget);
      expect(tester.getRect(pin).bottom, closeTo(tester.getRect(marker).bottom, 0.5));
    });

    testWidgets('long-pressing "Mulai jalan" runs the demo walk even with GPS', (tester) async {
      final route = parseOsrmRoute(jsonDecode(osrmSample));
      final locator = TrackingLocator(route.path.first);
      await openRoute(tester, locator: locator, planner: StaticPlanner(route));
      await tester.longPress(find.text('Mulai jalan'));
      await tester.pump();
      expect(locator.positions.hasListener, isFalse);
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      expect(find.text('Kamu sudah sampai'), findsWidgets);
    });
  });
}
