// Renders the app screens used in the pitch deck to PNG files. Skipped unless DECK_SHOTS names an output folder:
//   $env:DECK_SHOTS="..\render\out\deck-screens"; flutter test test\deck_screenshots_test.dart
// The camera previews are stand-ins (a food photo, a QR code), because flutter_test has no real camera.
// Every PNG is 1280 x 2772 (the demo phone: 400 x 866 logical at 3.2x).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawonfood/app.dart';
import 'package:pawonfood/core/data/providers.dart';
import 'package:pawonfood/core/services/camera_service.dart';
import 'package:pawonfood/core/services/location_service.dart';
import 'package:pawonfood/core/services/route_service.dart';
import 'package:pawonfood/core/widgets/pawon_map.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support.dart';

final _out = Platform.environment['DECK_SHOTS'];
final _frame = GlobalKey();

class _PictureCamera implements AppCamera {
  _PictureCamera(this.preview);
  final Widget preview;
  @override
  Future<CameraStatus> start() async => CameraStatus.ready;
  @override
  Widget buildPreview() => SizedBox.expand(child: preview);
  @override
  Future<String> capture() async => File('assets/images/food/ayam2.jpg').absolute.path;
  @override
  Future<CameraStatus> flip() async => CameraStatus.ready;
  @override
  bool get flashOn => false;
  @override
  Future<void> toggleFlash() async {}
  @override
  Future<void> dispose() async {}
}

final _foodPreview = Image.asset('assets/images/food/ayam2.jpg', fit: BoxFit.cover);
final _qrPreview = ColoredBox(
  color: const Color(0xFF3A3A36),
  child: Center(
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: QrImageView(data: 'PAWON-RSV-c1', size: 190, padding: EdgeInsets.zero),
    ),
  ),
);

List<Override> _overrides({Widget? cameraPreview, Duration scanDelay = Duration.zero}) => [
      mockDataProvider.overrideWithValue(loadMockData()),
      clockProvider.overrideWithValue(() => fixedNow),
      simulatedReplyDelayProvider.overrideWithValue(Duration.zero),
      simulatedOfferDelayProvider.overrideWithValue(Duration.zero),
      simulatedScanDelayProvider.overrideWithValue(scanDelay),
      randomProvider.overrideWithValue(Random(7)),
      tilesEnabledProvider.overrideWithValue(false),
      deviceLocatorProvider.overrideWithValue(const NoGpsLocator()),
      routePlannerProvider.overrideWithValue(const NoRoutePlanner()),
      if (cameraPreview != null) cameraFactoryProvider.overrideWithValue(() => _PictureCamera(cameraPreview)),
    ];

Future<void> _loadAllFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final f in manifest) {
    final loader = FontLoader(f['family'] as String);
    for (final a in f['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(a['asset'] as String));
    }
    await loader.load();
  }
}

const _deckPixelRatio = 3.2;

void _deckPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2772);
  tester.view.devicePixelRatio = _deckPixelRatio;
  addTearDown(tester.view.reset);
  useReducedMotion(tester);
}

Future<void> _start(WidgetTester tester, List<Override> overrides) async {
  _deckPhone(tester);
  await tester.pumpWidget(RepaintBoundary(key: _frame, child: ProviderScope(overrides: overrides, child: const PawonApp())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sudah punya akun? Masuk'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'rafi@email.com');
  await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
  await tester.tap(find.widgetWithText(InkWell, 'Masuk'));
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first));

Future<void> _settleImages(WidgetTester tester) async {
  for (var round = 0; round < 2; round++) {
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Scaffold).first);
      final providers = <ImageProvider>[];
      for (final e in find.byType(Image).evaluate()) {
        providers.add((e.widget as Image).image);
      }
      for (final e in find.byType(DecoratedBox).evaluate()) {
        final d = (e.widget as DecoratedBox).decoration;
        if (d is BoxDecoration && d.image != null) providers.add(d.image!.image);
      }
      for (final e in find.byType(Ink).evaluate()) {
        final d = (e.widget as Ink).decoration;
        if (d is BoxDecoration && d.image != null) providers.add(d.image!.image);
      }
      for (final p in providers) {
        await precacheImage(p, ctx).timeout(const Duration(seconds: 5), onTimeout: () {});
      }
    });
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settleImages(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _deckPixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final skip = _out == null || _out!.isEmpty;
  setUpAll(_loadAllFonts);

  testWidgets('B5 Beranda', skip: skip, (tester) async {
    await _start(tester, _overrides());
    await _shot(tester, 'b5-beranda');
  });

  testWidgets('B8 Detail makanan', skip: skip, (tester) async {
    await _start(tester, _overrides());
    unawaited(_router(tester).push('/listing/l_ayam2'));
    await tester.pumpAndSettle();
    await _shot(tester, 'b8-detail');
  });

  testWidgets('C13 Kamera terdeteksi and C15 Cek dan bagikan', skip: skip, (tester) async {
    await _start(tester, _overrides(cameraPreview: _foodPreview));
    unawaited(_router(tester).push('/share/camera'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await _shot(tester, 'c13-kamera');
    await tester.tap(find.bySemanticsLabel('Ambil foto'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await _shot(tester, 'c15-cek-bagikan');
  });

  testWidgets('B10 Chat tawaran diterima', skip: skip, (tester) async {
    await _start(tester, _overrides());
    unawaited(_router(tester).push('/chat/c1'));
    await tester.pumpAndSettle();
    await _shot(tester, 'b10-chat');
  });

  testWidgets('B10b Pindai QR', skip: skip, (tester) async {
    await _start(tester, _overrides(cameraPreview: _qrPreview, scanDelay: const Duration(hours: 1)));
    unawaited(_router(tester).push('/scan/c1'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await _shot(tester, 'b10b-pindai-qr');
  });

  testWidgets('D17 Profil', skip: skip, (tester) async {
    await _start(tester, _overrides());
    _router(tester).go('/profile');
    await tester.pumpAndSettle();
    await _shot(tester, 'd17-profil');
  });
}
