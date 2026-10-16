import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/providers.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/core/services/camera_service.dart';
import 'package:pawonfood/core/services/food_validator.dart';
import 'package:pawonfood/core/services/validators.dart';
import 'package:pawonfood/core/widgets/app_button.dart';
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

/// Answers only when the test completes it, so the form can be seen while the check is still running.
class SlowValidator implements FoodValidator {
  final answer = Completer<ValidationResult>();

  @override
  Future<ValidationResult> validate(String imagePath) => answer.future;
}

/// A capture that is already in place when the form opens.
class FixedCapture extends ShareCaptureNotifier {
  FixedCapture(this.initial);
  final ShareCapture? initial;

  @override
  ShareCapture? build() => initial;
}

void main() {
  setUpAll(loadAppFonts);

  Future<ProviderContainer> pumpShare(WidgetTester tester, {required List<Override> overrides, String initial = '/share/camera', bool settle = true}) async {
    usePhoneScreen(tester);
    final router = GoRouter(initialLocation: initial, routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Beranda'))),
      GoRoute(path: '/share/camera', builder: (_, _) => const CameraScreen()),
      GoRoute(path: '/share/form', builder: (_, _) => const ShareFormScreen()),
      GoRoute(path: '/share/done/:id', builder: (_, s) => Scaffold(body: Text('done ${s.pathParameters['id']}'))),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [...testOverrides(), ...overrides], child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
    await tester.pump(const Duration(seconds: 2)); // camera start
    // A check that is still running keeps the spinner turning, so such a test cannot wait for the screen to settle.
    if (settle) await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  }

  /// Whether "Bagikan sekarang" is switched off.
  bool publishDisabled(WidgetTester tester) => tester.widget<AppButton>(find.widgetWithText(AppButton, 'Bagikan sekarang')).onPressed == null;

  Future<void> shoot(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Ambil foto'));
    await tester.pumpAndSettle();
  }

  group('camera (step 1)', () {
    testWidgets('is a plain camera: no scan effect or detection box, in either mode', (tester) async {
      for (final cloud in [false, true]) {
        await pumpShare(tester, overrides: [
          cameraFactoryProvider.overrideWithValue(FakeCamera.new),
          cloudValidatorProvider.overrideWithValue(cloud),
          foodValidatorProvider.overrideWithValue(ScriptedValidator([approved])),
        ]);
        expect(find.text('Arahkan kamera ke makanan'), findsOneWidget);
        expect(find.text('AI sedang memindai...'), findsNothing);
        expect(find.text('Lauk matang'), findsNothing);
        expect(find.text('Makanan terdeteksi, siap difoto'), findsNothing);
      }
    });

    testWidgets('the shutter opens the form at once; the AI check runs behind it', (tester) async {
      final validator = SlowValidator();
      await pumpShare(tester, settle: false, overrides: [cameraFactoryProvider.overrideWithValue(FakeCamera.new), foodValidatorProvider.overrideWithValue(validator)]);
      await tester.tap(find.bySemanticsLabel('Ambil foto'));
      await tester.pump(); // the photo is taken and the route is pushed
      await tester.pump(const Duration(milliseconds: 600)); // the page transition
      expect(find.byType(ShareFormScreen), findsOneWidget);
      expect(find.text('AI sedang mengenali makanan...'), findsOneWidget);

      validator.answer.complete(approved);
      await tester.pumpAndSettle();
      expect(find.text('AI sedang mengenali makanan...'), findsNothing);
      expect(find.text('Foto lolos validasi'), findsOneWidget);
    });

    testWidgets('a blurry photo is explained on the form, blocks publishing and goes back to the camera', (tester) async {
      final validator = ScriptedValidator([const ValidationResult(verdict: AiVerdict.retake, message: msgBlurry, imageQuality: ImageQuality.blurry)]);
      final c = await pumpShare(tester, overrides: [cameraFactoryProvider.overrideWithValue(FakeCamera.new), foodValidatorProvider.overrideWithValue(validator)]);
      await shoot(tester);
      expect(find.byType(ShareFormScreen), findsOneWidget);
      expect(find.text('Foto kurang jelas'), findsOneWidget);
      expect(find.text(msgBlurry), findsOneWidget);

      final before = c.read(listingsProvider).length;
      expect(publishDisabled(tester), isTrue, reason: 'the reason is on screen, so the button is simply off');
      await tester.tap(find.text('Bagikan sekarang'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(c.read(listingsProvider).length, before);

      await tester.tap(find.text('Foto ulang'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareFormScreen), findsNothing);
      expect(find.text('Tips foto'), findsOneWidget, reason: 'back to the shutter controls');
    });

    testWidgets('a failed check is never treated as passed; "Coba lagi" re-checks the same photo', (tester) async {
      final camera = FakeCamera();
      final validator = ScriptedValidator([const ValidationUnavailable(ValidationFailure.timeout), approved]);
      final c = await pumpShare(tester, overrides: [cameraFactoryProvider.overrideWithValue(() => camera), foodValidatorProvider.overrideWithValue(validator)]);
      await shoot(tester);
      expect(find.text('Pemeriksaan AI gagal'), findsNWidgets(2), reason: 'the status line and the explanation');
      expect(find.textContaining('Foto belum dianggap lolos.'), findsOneWidget);
      expect(c.read(shareCaptureProvider)?.eligible, isFalse);

      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Foto lolos validasi'), findsOneWidget);
      expect(find.text('Coba lagi'), findsNothing);
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
      expect(find.text('Pemeriksaan AI gagal'), findsNWidgets(2));
    });
  });

  group('review form (step 2)', () {
    Future<ProviderContainer> pumpForm(WidgetTester tester, ShareCapture? capture) =>
        pumpShare(tester, initial: '/share/form', overrides: [shareCaptureProvider.overrideWith(() => FixedCapture(capture))]);

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

    testWidgets('the AI pre-selects the health tags; the provider can change them and they are published', (tester) async {
      const result = ValidationResult(
        verdict: AiVerdict.approved,
        category: FoodCategory.makananMatang,
        suggestedName: 'Sayur lodeh',
        suggestedHealthTags: {HealthTag.sayurBuah, HealthTag.tidakDigoreng},
      );
      final c = await pumpForm(tester, const ShareCapture(photoPath: 'p.jpg', result: result));
      await tester.scrollUntilVisible(find.text('Pilihan sehat'), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text('Pilihan sehat'), findsOneWidget);
      expect(find.text('Ditandai otomatis oleh AI. Ubah kalau kurang tepat.'), findsOneWidget);
      expect(find.text('Ide resep'), findsNothing, reason: 'recipes are for fresh ingredients only');
      await tester.ensureVisible(find.text('Protein')); // clear of the sticky bar
      await tester.pumpAndSettle();
      await tester.tap(find.text('Protein')); // add one the AI did not see
      await tester.tap(find.text('Tidak digoreng')); // remove one
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bagikan sekarang'));
      await tester.pumpAndSettle();
      expect(c.read(listingsProvider).first.healthTags, {HealthTag.sayurBuah, HealthTag.protein});
    });

    testWidgets('"Bawa wadah sendiri" turns "Bisa diantar" off and is published', (tester) async {
      const result = ValidationResult(verdict: AiVerdict.approved, category: FoodCategory.makananMatang, suggestedName: 'Sayur lodeh');
      final c = await pumpForm(tester, const ShareCapture(photoPath: 'p.jpg', result: result));
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Bisa diantar (< 1 km)'), 100, scrollable: scroll);
      await tester.ensureVisible(find.text('Bisa diantar (< 1 km)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bisa diantar (< 1 km)'));
      await tester.pumpAndSettle();
      expect(find.text('Ongkir'), findsOneWidget, reason: 'delivery on for wrapped food');

      await tester.scrollUntilVisible(find.text('Bawa wadah sendiri'), -100, scrollable: scroll);
      await tester.ensureVisible(find.text('Bawa wadah sendiri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bawa wadah sendiri'));
      await tester.pumpAndSettle();
      expect(find.text('Penerima diminta membawa wadah bersih sendiri. Hemat kemasan sekali pakai.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Antar hanya untuk makanan yang sudah dibungkus.'), 100, scrollable: scroll);
      expect(find.text('Ongkir'), findsNothing, reason: 'delivery was turned off');

      await tester.ensureVisible(find.text('Bagikan sekarang'));
      await tester.tap(find.text('Bagikan sekarang'));
      await tester.pumpAndSettle();
      final l = c.read(listingsProvider).first;
      expect((l.packaging, l.canDeliver), (Packaging.wadahSendiri, false));
    });

    testWidgets('sealed food has no Kemasan choice', (tester) async {
      const result = ValidationResult(verdict: AiVerdict.approved, category: FoodCategory.sealedFood, suggestedName: 'Roti');
      await pumpForm(tester, const ShareCapture(photoPath: 'p.jpg', result: result));
      await tester.scrollUntilVisible(find.text('Pilihan sehat'), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text('Kemasan'), findsNothing);
      expect(find.text('Bawa wadah sendiri'), findsNothing);
    });

    testWidgets('fresh ingredients show recipe ideas from the name; the chosen recipe is published', (tester) async {
      const result = ValidationResult(verdict: AiVerdict.approved, category: FoodCategory.bahanMentah, suggestedName: 'Wortel dan kol', suggestedHealthTags: {HealthTag.sayurBuah});
      final c = await pumpForm(tester, const ShareCapture(photoPath: 'p.jpg', result: result));
      await tester.scrollUntilVisible(find.text('Ide resep'), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text('Ide resep'), findsOneWidget);
      expect(find.text('Minta ide dari AI'), findsNothing, reason: 'no cloud server configured');
      await tester.scrollUntilVisible(find.text('Tumis Kol Wortel'), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text('Sup Wortel Kol'), findsOneWidget);
      await tester.ensureVisible(find.text('Tumis Kol Wortel')); // clear of the sticky "Bagikan sekarang" bar
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tumis Kol Wortel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bagikan sekarang'));
      await tester.pumpAndSettle();
      final listing = c.read(listingsProvider).first;
      expect(listing.isOwn, isTrue, reason: 'published');
      expect(listing.category, FoodCategory.bahanMentah);
      expect(listing.recipe?.id, 'r_tumis_kol_wortel');
    });

    testWidgets('the AI answer arriving later fills the empty fields but keeps what the provider typed', (tester) async {
      final validator = SlowValidator();
      final c = await pumpShare(tester, initial: '/share/form', settle: false, overrides: [foodValidatorProvider.overrideWithValue(validator)]);
      unawaited(c.read(shareCaptureProvider.notifier).start('p.jpg'));
      await tester.pump();
      expect(find.text('AI sedang mengenali makanan...'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Soto buatan ibu');

      validator.answer.complete(const ValidationResult(
        verdict: AiVerdict.approved,
        category: FoodCategory.makananMatang,
        suggestedName: 'Ayam goreng',
        suggestedDescription: 'Ayam goreng bumbu kuning, 4 potong.',
        suggestedHealthTags: {HealthTag.protein},
      ));
      await tester.pumpAndSettle();
      expect(find.text('Soto buatan ibu'), findsOneWidget, reason: 'a name typed by hand is not overwritten');
      expect(find.text('Ayam goreng'), findsNothing);
      expect(find.text('Ayam goreng bumbu kuning, 4 potong.'), findsOneWidget);
      expect(find.text('Lauk matang'), findsOneWidget, reason: 'the category pill');

      await tester.tap(find.text('Bagikan sekarang'));
      await tester.pumpAndSettle();
      final listing = c.read(listingsProvider).first;
      expect(listing.name, 'Soto buatan ibu');
      expect(listing.description, 'Ayam goreng bumbu kuning, 4 potong.');
      expect(listing.healthTags, {HealthTag.protein});
    });

    testWidgets('publishing while the AI is still checking asks to wait', (tester) async {
      final c = await pumpShare(tester, initial: '/share/form', settle: false, overrides: [shareCaptureProvider.overrideWith(() => FixedCapture(const ShareCapture(photoPath: 'p.jpg')))]);
      await tester.enterText(find.byType(TextField).first, 'Ayam goreng');
      final before = c.read(listingsProvider).length;
      expect(find.text('AI sedang mengenali makanan...'), findsOneWidget);
      expect(publishDisabled(tester), isTrue);
      await tester.tap(find.text('Bagikan sekarang'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.read(listingsProvider).length, before);
    });

    testWidgets('the AI status line is a live region, so a screen reader hears the answer', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpForm(tester, const ShareCapture(photoPath: 'p.jpg', result: approved));
      expect(tester.getSemantics(find.text('Foto lolos validasi')).flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('a description longer than the limit is cut while typing and refused by publish', (tester) async {
      final c = await pumpForm(tester, const ShareCapture(photoPath: 'p.jpg', result: approved));
      await tester.enterText(find.widgetWithText(TextField, 'Contoh: Ayam goreng bumbu kuning, 4 potong').first, 'a' * 300);
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text.length, descriptionMaxLength);
      expect(Validators.description('a' * (descriptionMaxLength + 1)), isNotNull);
      expect(Validators.description('a' * descriptionMaxLength), isNull);
      expect(c.read(listingsProvider).first.isOwn, isFalse);
    });

    testWidgets('a name without a known ingredient shows that no recipe matches', (tester) async {
      const result = ValidationResult(verdict: AiVerdict.approved, category: FoodCategory.bahanMentah, suggestedName: 'Durian');
      await pumpForm(tester, const ShareCapture(photoPath: 'p.jpg', result: result));
      await tester.scrollUntilVisible(find.text('Belum ada resep yang cocok.'), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text('Belum ada resep yang cocok.'), findsOneWidget);
    });
  });
}
