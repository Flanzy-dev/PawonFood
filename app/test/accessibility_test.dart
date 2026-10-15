import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/core/widgets/food_card.dart';
import 'package:pawonfood/core/widgets/form_controls.dart';
import 'package:pawonfood/core/widgets/layout_widgets.dart';
import 'package:pawonfood/core/widgets/mini_food_card.dart';
import 'package:pawonfood/core/widgets/navigation_widgets.dart';
import 'package:pawonfood/core/widgets/option_row.dart';
import 'package:pawonfood/core/widgets/settings_list.dart';
import 'package:pawonfood/core/data/session_repository.dart';
import 'package:pawonfood/features/auth/onboarding_screen.dart';
import 'package:pawonfood/features/auth/welcome_screen.dart';
import 'package:pawonfood/features/share/share_form_screen.dart';

import 'support.dart';

/// A small phone (360 x 640 dp) with the system font at [scale]: the layouts must not overflow.
void useSmallPhone(WidgetTester tester, double scale) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  useReducedMotion(tester);
}

Widget host(Widget child) => ProviderScope(
      overrides: testOverrides(),
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  setUpAll(loadAppFonts);

  group('large text does not overflow', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('Welcome at ${scale}x', (tester) async {
        useSmallPhone(tester, scale);
        await tester.pumpWidget(ProviderScope(overrides: testOverrides(), child: MaterialApp(theme: AppTheme.light(), home: const WelcomeScreen())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Daftar'), findsWidgets);
      });

      testWidgets('Onboarding at ${scale}x', (tester) async {
        useSmallPhone(tester, scale);
        await tester.pumpWidget(ProviderScope(overrides: testOverrides(), child: MaterialApp(theme: AppTheme.light(), home: const OnboardingScreen())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Bagikan makanan berlebih'), findsOneWidget);
        expect(find.text('Lanjut'), findsOneWidget);
      });

      testWidgets('food cards, segmented control and tab bar at ${scale}x', (tester) async {
        useSmallPhone(tester, scale);
        final l = loadMockData().listings.firstWhere((l) => l.id == 'l_ayam');
        await tester.pumpWidget(
          host(
            Column(children: [
              FoodCard(listing: l, distance: 296, onTap: () {}),
              MiniFoodCard(listing: l, distance: 296, onTap: () {}),
              SegmentedControl(options: const ['Saya menerima', 'Saya membagikan'], selected: 0, onChanged: (_) {}),
              PawonBottomNav(currentIndex: 0, onTap: (_) {}, onShare: () {}),
            ]),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('controls expose their tap action to screen readers', () {
    testWidgets('OptionRow and SettingsRow', (tester) async {
      usePhoneScreen(tester);
      final handle = tester.ensureSemantics();
      var option = 0, setting = 0;
      await tester.pumpWidget(
        host(
          Column(children: [
            OptionRow(title: 'Tunai di tempat', selected: false, onTap: () => option++),
            SettingsRow(title: 'Bahasa', onTap: () => setting++),
          ]),
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Tunai di tempat'));
      tester.semantics.tap(find.semantics.byLabel('Bahasa'));
      expect([option, setting], [1, 1]);
      handle.dispose();
    });

    testWidgets('AppTextField is named for screen readers even without a visible label', (tester) async {
      usePhoneScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const AppTextField(label: '', semanticLabel: 'Harga per porsi', prefix: 'Rp', suffixText: '/porsi')));
      expect(find.bySemanticsLabel(RegExp('Harga per porsi')), findsOneWidget);
      handle.dispose();
    });
  });

  group('SegmentedControl layout', () {
    testWidgets('labels sit in the vertical middle of the 56 dp track and of the white thumb', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(SegmentedControl(options: const ['Gratis', 'Jual murah'], selected: 1, onChanged: (_) {})));
      await tester.pumpAndSettle();
      final track = tester.getRect(find.byType(SegmentedControl));
      expect(track.height, 56);
      for (final label in ['Gratis', 'Jual murah']) {
        expect(tester.getCenter(find.text(label)).dy, closeTo(track.center.dy, 1), reason: '$label is centred vertically');
      }
      // The selected label is also centred in the thumb: the thumb is the white box behind "Jual murah".
      final thumb = tester.getRect(find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox)).first);
      expect(thumb.height, 42);
      expect(tester.getCenter(find.text('Jual murah')).dx, closeTo(thumb.center.dx, 1));
      expect(tester.getCenter(find.text('Jual murah')).dy, closeTo(thumb.center.dy, 1));
    });
  });

  group('Cek & bagikan bar', () {
    /// Pumps the form on a screen [width] dp wide and measures the bar: (lines of consent text, bar height).
    Future<(int, double)> measure(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width * 3, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      useReducedMotion(tester);
      await tester.pumpWidget(ProviderScope(overrides: testOverrides(), child: MaterialApp(theme: AppTheme.light(), home: const ShareFormScreen())));
      await tester.pumpAndSettle();
      final text = tester.getRect(find.textContaining('Dengan membagikan'));
      final button = tester.getRect(find.widgetWithText(InkWell, 'Bagikan sekarang'));
      final bar = tester.getRect(find.byType(StickyBottomBar));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(text.top - bar.top, closeTo(8, 1), reason: '8 dp of room under the bar line, whatever the number of lines');
      expect(button.top - text.bottom, closeTo(14, 1), reason: '14 dp between the consent text and the button');
      expect(screen.height - button.bottom, 8, reason: '8 dp under the button (no gesture inset in tests)');
      return ((text.height / 18).round(), bar.height);
    }

    testWidgets('the bar follows the number of text lines: one line is 18 dp shorter than two', (tester) async {
      final (narrowLines, narrowBar) = await measure(tester, 320);
      final (wideLines, wideBar) = await measure(tester, 520);
      expect(narrowLines, 2);
      expect(wideLines, 1);
      expect(narrowBar - wideBar, closeTo(18, 1));
    });
  });

  group('safeguards', () {
    testWidgets('Keluar asks first; "Batal" keeps the session, "Keluar" ends it', (tester) async {
      usePhoneScreen(tester);
      await signIn(tester);
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      final list = find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.widgetWithText(InkWell, 'Keluar'), 200, scrollable: list);
      await tester.drag(list, const Offset(0, -200)); // the button must clear the bottom nav
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.text('Profil').first));

      await tester.tap(find.widgetWithText(InkWell, 'Keluar'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari PawonFood?'), findsOneWidget);
      expect(container.read(sessionProvider), isNotNull, reason: 'nothing happens before the user confirms');

      await tester.tap(find.widgetWithText(InkWell, 'Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari PawonFood?'), findsNothing);
      expect(container.read(sessionProvider), isNotNull);

      await tester.tap(find.widgetWithText(InkWell, 'Keluar'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(InkWell, 'Keluar')));
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider), isNull);
    });

    testWidgets('an incomplete reset code shows a written error, not only a shake', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(appUnderTest());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sudah punya akun? Masuk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lupa password?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'rafi@email.com');
      await tester.tap(find.widgetWithText(InkWell, 'Kirim kode'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '123');
      await tester.tap(find.widgetWithText(InkWell, 'Verifikasi'));
      await tester.pump();
      expect(find.text('Masukkan 6 angka kode dari emailmu.'), findsOneWidget);
      expect(find.textContaining('Kirim ulang kode dalam 01:'), findsOneWidget);
    });
  });
}
