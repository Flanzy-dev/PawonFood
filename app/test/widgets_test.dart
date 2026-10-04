import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pawonfood/core/models/reward.dart';
import 'package:pawonfood/core/services/food_label.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/core/widgets/food_card.dart';
import 'package:pawonfood/core/widgets/form_controls.dart';
import 'package:pawonfood/core/widgets/pills.dart';
import 'package:pawonfood/core/widgets/reward_card.dart';
import 'package:pawonfood/features/auth/register_screen.dart';

import 'support.dart';

Widget host(Widget child) => ProviderScope(
      overrides: testOverrides(),
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  setUpAll(loadAppFonts);

  group('FoodCard', () {
    testWidgets('shows struck-through price, bold price, stock and status label', (tester) async {
      usePhoneScreen(tester);
      final l = loadMockData().listings.firstWhere((l) => l.id == 'l_ayam');
      await tester.pumpWidget(host(FoodCard(listing: l, distance: 296, onTap: () {})));
      expect(find.text('Ayam Goreng Sisa Katering'), findsOneWidget);
      expect(find.text('Warteg Bu Siti'), findsOneWidget);
      expect(find.text('Pahlawan Pangan'), findsOneWidget);
      expect(find.text('Rp15.000'), findsOneWidget);
      expect(find.text('Rp5.000'), findsOneWidget);
      expect(find.text('Sisa 2 porsi'), findsOneWidget);
      expect(find.text('Populer'), findsOneWidget);
      expect(find.text('AI'), findsNothing);
      expect(find.text('300 m'), findsOneWidget);
    });

    testWidgets('price sits bottom-right and distance bottom-left, with no chat icon', (tester) async {
      usePhoneScreen(tester);
      final l = loadMockData().listings.firstWhere((l) => l.id == 'l_ayam');
      await tester.pumpWidget(host(FoodCard(listing: l, distance: 296, onTap: () {})));
      final card = tester.getRect(find.byType(FoodCard));
      final price = tester.getRect(find.text('Rp5.000'));
      final distance = tester.getRect(find.text('300 m'));
      expect(price.right, closeTo(card.right - 12, 1)); // right-aligned to the card padding
      expect(price.center.dy, greaterThan(card.center.dy)); // lower half
      expect(distance.center.dx, lessThan(price.center.dx));
      expect(find.byIcon(LucideIcons.messageSquare), findsNothing);
    });

    testWidgets('free food shows GRATIS and no price', (tester) async {
      usePhoneScreen(tester);
      final l = loadMockData().listings.firstWhere((l) => l.id == 'l_lodeh');
      await tester.pumpWidget(host(FoodCard(listing: l, distance: 446, onTap: () {})));
      expect(find.text('GRATIS'), findsOneWidget);
      expect(find.textContaining('Rp'), findsNothing);
      expect(find.text('450 m'), findsOneWidget);
    });
  });

group('FoodLabelBadge', () {
    testWidgets('renders every label', (tester) async {
      for (final l in FoodLabel.values) {
        await tester.pumpWidget(host(FoodLabelBadge(l)));
        expect(find.text(l.label), findsOneWidget);
      }
    });
  });

  group('RewardCard', () {
    const voucher = Reward(id: 'r', title: 'Voucher belanja minimarket', subtitle: '', tile: 'Rp', cost: 200, tone: 'sand');
    Widget card(int points, VoidCallback onTap) => host(SizedBox(width: 179, height: 179, child: RewardCard(reward: voucher, points: points, onTap: onTap)));

    testWidgets('shows the cost when the balance is enough and is tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(card(300, () => taps++));
      expect(find.text('200 poin'), findsOneWidget);
      expect(find.textContaining('Kurang'), findsNothing);
      await tester.tap(find.byType(RewardCard));
      expect(taps, 1);
    });

    testWidgets('shows the missing points and dims the tile when the balance is too low', (tester) async {
      await tester.pumpWidget(card(150, () {}));
      expect(find.text('Kurang 50 poin'), findsOneWidget);
      expect(find.text('200 poin'), findsNothing);
      expect(tester.widget<Opacity>(find.descendant(of: find.byType(RewardTile), matching: find.byType(Opacity))).opacity, lessThan(1));
    });

    testWidgets('the grid lays out two square cards per row', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(Padding(padding: const EdgeInsets.all(16), child: RewardGrid(rewards: const [voucher, voucher, voucher], points: 0, onTap: (_) {}))));
      final r = [for (var i = 0; i < 3; i++) tester.getRect(find.byType(RewardCard).at(i))];
      expect(r[0].width, closeTo(r[0].height, 0.1));
      expect(r[1].top, r[0].top);
      expect(r[2].top, greaterThan(r[0].bottom));
    });
  });

  group('form controls', () {
    testWidgets('QtyStepper keeps the value within its range', (tester) async {
      var value = 1;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) => MaterialApp(home: Scaffold(body: QtyStepper(value: value, max: 2, onChanged: (v) => setState(() => value = v)))),
      ));
      await tester.tap(find.bySemanticsLabel('Kurangi porsi'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget); // already at the minimum
      await tester.tap(find.bySemanticsLabel('Tambah porsi'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Tambah porsi'));
      await tester.pump();
      expect(find.text('2'), findsOneWidget); // capped at max
    });

    testWidgets('TimeChips disables times in the past', (tester) async {
      DateTime? picked;
      final times = [fixedNow.subtract(const Duration(hours: 1)), fixedNow.add(const Duration(hours: 1))];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: TimeChips(times: times, selected: null, now: fixedNow, onSelected: (t) => picked = t))));
      await tester.tap(find.text('19.00'));
      expect(picked, isNull);
      await tester.tap(find.text('21.00'));
      expect(picked, times[1]);
    });
  });

  group('Daftar akun', () {
    testWidgets('shows inline errors after a failed submit and keeps the button disabled until valid', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(ProviderScope(overrides: testOverrides(), child: MaterialApp(theme: AppTheme.light(), home: const RegisterScreen())));
      expect(find.text('Nama wajib diisi'), findsNothing);

      await tester.tap(find.widgetWithText(InkWell, 'Buat akun'));
      await tester.pump();
      expect(find.text('Nama wajib diisi'), findsOneWidget);
      expect(find.text('Email atau nomor HP wajib diisi'), findsOneWidget);
      expect(find.text('Password minimal 8 karakter'), findsWidgets);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Rafi Pratama');
      await tester.enterText(fields.at(1), 'rafi@email');
      await tester.enterText(fields.at(2), 'abc');
      await tester.pump();
      expect(find.text('Nama wajib diisi'), findsNothing);
      expect(find.text('Format email atau nomor HP tidak valid'), findsOneWidget);
      final button = tester.widget<InkWell>(find.widgetWithText(InkWell, 'Buat akun'));
      expect(button.onTap, isNull);

      await tester.enterText(fields.at(1), 'rafi@email.com');
      await tester.enterText(fields.at(2), 'abcd1234');
      await tester.pump();
      expect(find.text('Format email atau nomor HP tidak valid'), findsNothing);
      expect(tester.widget<InkWell>(find.widgetWithText(InkWell, 'Buat akun')).onTap, isNotNull);
    });
  });
}
