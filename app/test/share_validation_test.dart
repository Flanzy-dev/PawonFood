import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/providers.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/services/camera_service.dart';
import 'package:pawonfood/core/services/food_validator.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/features/share/camera_screen.dart';
import 'package:pawonfood/features/share/share_form_screen.dart';
import 'package:pawonfood/features/share/share_state.dart';

import 'support.dart';

class FakeCamera implements AppCamera {
  var captures = 0;

  @override
  Future<CameraStatus> start() async => CameraStatus.ready;
  @override
  Widget buildPreview() => const SizedBox.expand();
  @override
  Future<String> capture() async {
    captures++;
    return 'photo_$captures.jpg';
  }

  @override
  Future<CameraStatus> flip() async => CameraStatus.ready;
  @override
  bool get flashOn => false;
  @override
  Future<void> toggleFlash() async {}
  @override
  Future<void> dispose() async {}
}

/// Answers with the queued results in order; a [ValidationUnavailable] in the queue is thrown.
class ScriptedValidator implements FoodValidator {
  ScriptedValidator(this.queue);
  final List<Object> queue;
  final paths = <String>[];

  @override
  Future<ValidationResult> validate(String imagePath) async {
    paths.add(imagePath);
    final next = queue.removeAt(0);
    if (next is ValidationUnavailable) throw next;
    return next as ValidationResult;
  }
}

const approved = ValidationResult(verdict: AiVerdict.approved, category: FoodCategory.makananMatang, suggestedName: 'Ayam goreng', message: 'Foto lolos validasi');

void main() {
  setUpAll(loadAppFonts);

  Future<ProviderContainer> pumpShare(WidgetTester tester, {required List<Override> overrides, String initial = '/share/camera'}) async {
    usePhoneScreen(tester);
    final router = GoRouter(initialLocation: initial, routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Beranda'))),
      GoRoute(path: '/share/camera', builder: (_, _) => const CameraScreen()),
      GoRoute(path: '/share/form', builder: (_, _) => const ShareFormScreen()),
      GoRoute(path: '/share/done/:id', builder: (_, s) => Scaffold(body: Text('done ${s.pathParameters['id']}'))),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [...testOverrides(), ...overrides], child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
    await tester.pump(const Duration(seconds: 2)); // camera start + the simulated live detection
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  }

  Future<void> shoot(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Ambil foto'));
    await tester.pumpAndSettle();
  }

  group('camera (step 1)', () {
    testWidgets('a blurry photo asks for a retake and does not open the form', (tester) async {
      final validator = ScriptedValidator([const ValidationResult(verdict: AiVerdict.retake, message: msgBlurry, imageQuality: ImageQuality.blurry)]);
      await pumpShare(tester, overrides: [cameraFactoryProvider.overrideWithValue(FakeCamera.new), foodValidatorProvider.overrideWithValue(validator)]);
      await shoot(tester);
      expect(find.text('Foto kurang jelas'), findsOneWidget);
      expect(find.text(msgBlurry), findsOneWidget);
      expect(find.byType(ShareFormScreen), findsNothing);
      await tester.tap(find.text('Foto ulang'));
      await tester.pumpAndSettle();
      expect(find.text('Tips foto'), findsOneWidget, reason: 'back to the shutter controls');
    });

    testWidgets('visible spoilage is rejected with what the AI saw', (tester) async {
      final validator = ScriptedValidator([
        const ValidationResult(verdict: AiVerdict.rejected, message: msgSpoiled, visualCondition: VisualCondition.visibleSpoilage, visibleSigns: ['jamur hijau di tepi roti']),
      ]);
      await pumpShare(tester, overrides: [cameraFactoryProvider.overrideWithValue(FakeCamera.new), foodValidatorProvider.overrideWithValue(validator)]);
      await shoot(tester);
      expect(find.text('Ada tanda tidak layak'), findsOneWidget);
      expect(find.text('Terlihat: jamur hijau di tepi roti.'), findsOneWidget);
      expect(find.byType(ShareFormScreen), findsNothing);
    });

    testWidgets('a failed check is never treated as passed; "Coba lagi" re-checks the same photo', (tester) async {
      final camera = FakeCamera();
      final validator = ScriptedValidator([const ValidationUnavailable(ValidationFailure.timeout), approved]);
      final c = await pumpShare(tester, overrides: [cameraFactoryProvider.overrideWithValue(() => camera), foodValidatorProvider.overrideWithValue(validator)]);
      await shoot(tester);
      expect(find.text('Pemeriksaan AI gagal'), findsOneWidget);
      expect(find.textContaining('Foto belum dianggap lolos.'), findsOneWidget);
      expect(c.read(shareCaptureProvider), isNull);
      expect(find.byType(ShareFormScreen), findsNothing);

      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareFormScreen), findsOneWidget);
      expect(camera.captures, 1);
      expect(validator.paths, ['photo_1.jpg', 'photo_1.jpg']);
    });

    testWidgets('the simulated "Server AI gagal" demo mode shows the failed state', (tester) async {
      final c = await pumpShare(tester, overrides: [
        cameraFactoryProvider.overrideWithValue(FakeCamera.new),
        foodValidatorProvider.overrideWith((ref) => SimulatedFoodValidator(mode: () => ref.read(demoAiModeProvider), scanDelay: Duration.zero)),
      ]);
      c.read(demoAiModeProvider.notifier).state = DemoAiMode.serverDown;
      await tester.pumpAndSettle();
      await shoot(tester);
      expect(find.text('Pemeriksaan AI gagal'), findsOneWidget);
    });

    testWidgets('cloud mode shows no simulated live detection before the shot', (tester) async {
      await pumpShare(tester, overrides: [
        cameraFactoryProvider.overrideWithValue(FakeCamera.new),
        cloudValidatorProvider.overrideWithValue(true),
        foodValidatorProvider.overrideWithValue(ScriptedValidator([approved])),
      ]);
      expect(find.text('Lauk matang'), findsNothing);
      expect(find.text('Makanan terdeteksi, siap difoto'), findsNothing);
      expect(find.text('Arahkan kamera ke makanan'), findsOneWidget);
      await shoot(tester);
      expect(find.byType(ShareFormScreen), findsOneWidget);
    });
  });

  group('review form (step 2)', () {
    Future<ProviderContainer> pumpForm(WidgetTester tester, ShareCapture? capture) =>
        pumpShare(tester, initial: '/share/form', overrides: [shareCaptureProvider.overrideWith((ref) => capture)]);

    testWidgets('without a passed photo, publishing is blocked', (tester) async {
      final c = await pumpForm(tester, null);
      final before = c.read(listingsProvider).length;
      expect(find.text('Foto belum dicek AI'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Ayam goreng');
      await tester.tap(find.text('Bagikan sekarang'));
      await tester.pumpAndSettle();
      expect(find.text('Foto belum lolos pengecekan AI. Kembali ke kamera untuk foto ulang.'), findsOneWidget);
      expect(c.read(listingsProvider).length, before);
    });

    testWidgets('an unknown category must be picked; the AI notes and the safety disclaimer show', (tester) async {
      const result = ValidationResult(
        verdict: AiVerdict.pendingReview,
        message: 'AI belum yakin kategorinya. Pilih kategori yang sesuai sebelum membagikan.',
        suggestedName: 'Kue lapis',
        warnings: ['lebih dari satu jenis makanan'],
      );
      final c = await pumpForm(tester, const ShareCapture(photoPath: 'p.jpg', result: result));
      expect(find.text('Pilih kategori'), findsOneWidget);
      expect(find.text('Menunggu tinjauan manual'), findsOneWidget);
      expect(find.textContaining('Terlihat di foto: lebih dari satu jenis makanan.'), findsOneWidget);
      expect(find.textContaining('bukan jaminan keamanan pangan'), findsOneWidget);

      await tester.tap(find.text('Bagikan sekarang'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih kategori dulu'), findsOneWidget);
      expect(c.read(listingsProvider).first.isOwn, isFalse, reason: 'nothing published yet');

      await tester.tap(find.text('Ubah').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Makanan matang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bagikan sekarang'));
      await tester.pumpAndSettle();
      final listing = c.read(listingsProvider).first;
      expect(listing.isOwn, isTrue);
      expect(listing.category, FoodCategory.makananMatang);
      expect(listing.aiStatus, AiStatus.pendingReview);
      expect(listing.aiCategory, isNull);
      expect(find.textContaining('done '), findsOneWidget);
    });

    testWidgets('a manual category correction is published and recorded', (tester) async {
      final c = await pumpForm(tester, const ShareCapture(photoPath: 'p.jpg', result: approved));
      expect(find.text('Foto lolos validasi'), findsOneWidget);
      await tester.tap(find.text('Ubah').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bahan mentah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bagikan sekarang'));
      await tester.pumpAndSettle();
      final listing = c.read(listingsProvider).first;
      expect(listing.category, FoodCategory.bahanMentah);
      expect(listing.aiCategory, FoodCategory.makananMatang);
      expect(listing.categoryCorrected, isTrue);
      expect(listing.aiStatus, AiStatus.approved);
    });
  });
}
