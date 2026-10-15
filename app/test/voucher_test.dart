import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/core/data/chat_repository.dart';
import 'package:pawonfood/core/data/rewards_repository.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pawonfood/core/models/claimed_voucher.dart';
import 'package:pawonfood/core/services/formatters.dart';
import 'package:pawonfood/core/widgets/option_row.dart';
import 'package:pawonfood/features/payment/voucher_sheet.dart';

import 'support.dart';

/// Opens Ayam Goreng Lalapan (Rp7.000), takes it and lands on Pembayaran.
Future<ProviderContainer> openPayment(WidgetTester tester) async {
  usePhoneScreen(tester);
  await signIn(tester);
  await tester.scrollUntilVisible(find.text('Ayam Goreng Lalapan'), 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(find.text('Ayam Goreng Lalapan')); // clear of the tab bar
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ayam Goreng Lalapan'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ambil · Rp7.000'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pilih cara bayar'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.text('Pembayaran').first));
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Pembayaran: a food voucher from Voucher saya lowers the total, can be removed, and is spent only on payment', (tester) async {
    final container = await openPayment(tester);
    expect(find.text('Rp7.000'), findsWidgets);

    await tester.tap(find.text('Pakai voucher'));
    await tester.pumpAndSettle();
    expect(find.text('Potongan makanan Rp3.000'), findsOneWidget);
    expect(find.text('Voucher belanja minimarket'), findsNothing, reason: 'partner vouchers are not offered for food');
    await tester.tap(find.text('Potongan makanan Rp3.000'));
    await tester.pumpAndSettle();

    // Rincian shows only the code and the discount; the voucher card stays, now showing the applied voucher.
    expect(find.text('PWN-V-3001'), findsOneWidget);
    expect(find.text('−Rp3.000'), findsOneWidget);
    expect(find.text('Potongan makanan Rp3.000'), findsOneWidget);
    expect(find.text('PWN-V-3001 · s/d ${formatShortDate(fixedNow.add(const Duration(days: 40)))}'), findsOneWidget);
    expect(find.text('Pakai voucher'), findsNothing);
    expect(find.widgetWithText(InkWell, 'Pakai tunai di tempat'), findsOneWidget);
    var voucher = container.read(myVouchersProvider.notifier).byCode('PWN-V-3001')!;
    expect(voucher.used, isFalse, reason: 'applying is not spending');

    // Remove it: back to the full price, still usable.
    await tester.tap(find.descendant(of: find.byType(OptionRow), matching: find.byIcon(LucideIcons.x)));
    await tester.pumpAndSettle();
    expect(find.text('PWN-V-3001'), findsNothing);
    expect(find.byType(AppliedVoucherRow), findsNothing);
    expect(find.text('Pakai voucher'), findsOneWidget);

    // Apply again and pay by QRIS: the QRIS screen shows the payable amount.
    await tester.tap(find.text('Pakai voucher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Potongan makanan Rp3.000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QRIS'));
    await tester.tap(find.textContaining('Saya telah memeriksa kondisi makanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Bayar Rp4.000'));
    await tester.pumpAndSettle();
    expect(find.text('Rp4.000'), findsWidgets);
    await tester.tap(find.text('Cek status pembayaran'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(container.read(myVouchersProvider.notifier).byCode('PWN-V-3001')!.used, isFalse, reason: 'not paid yet');
    await tester.tap(find.text('Cek status pembayaran'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    voucher = container.read(myVouchersProvider.notifier).byCode('PWN-V-3001')!;
    expect(voucher.used, isTrue, reason: 'spent once the payment went through');
    expect(find.textContaining('Rp4.000 · QRIS · voucher −Rp3.000'), findsOneWidget);
  });

  testWidgets('Pembayaran: typed codes are checked with a clear reason', (tester) async {
    final container = await openPayment(tester);
    container.read(myVouchersProvider.notifier).add(ClaimedVoucher(
          reward: container.read(rewardByIdProvider('r_makan3'))!,
          code: 'PWN-V-9999',
          validUntil: fixedNow.subtract(const Duration(days: 1)),
        ));
    await tester.tap(find.text('Pakai voucher'));
    await tester.pumpAndSettle();

    Future<void> tryCode(String code, String message) async {
      await tester.enterText(find.byType(TextField).last, code);
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, 'Pakai kode'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget, reason: code);
    }

    await tryCode('PWN-V-0000', 'Kode tidak ditemukan.');
    await tryCode('PWN-V-1180', 'Voucher sudah dipakai.');
    await tryCode('PWN-V-9999', 'Voucher sudah kedaluwarsa.');
    await tryCode('PWN-V-5148', 'Voucher ini untuk mitra, tidak berlaku untuk makanan.');

    // A valid code, typed in lower case with a space, works.
    await tester.enterText(find.byType(TextField).last, 'pwn-v-3002 ');
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Pakai kode'));
    await tester.pumpAndSettle();
    expect(find.text('PWN-V-3002'), findsOneWidget);
    expect(find.text('−Rp5.000'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Pakai tunai di tempat'), findsOneWidget);
    // Rp7.000 − Rp5.000 = Rp2.000 payable (above the Rp1.000 floor).
    final conv = container.read(chatProvider).firstWhere((c) => c.pickup?.voucherCode == 'PWN-V-3002');
    expect(conv.pickup!.discount, 5000);
  });

  test('a voucher can never take the payment below Rp1.000', () {
    final c = makeContainer();
    final n = c.read(chatProvider.notifier);
    final id = n.claim('l_ayam');
    final price = n.amountOf(n.byId(id)!);
    expect(n.byId(id)!.pickup!.discount, 0);
    expect(n.applyVoucher(id, 'PWN-V-3002'), isNull);
    final discount = n.byId(id)!.pickup!.discount;
    expect(discount, price - ChatNotifier.minPayable, reason: 'the Rp5.000 voucher is cut so that Rp1.000 is left to pay');
    expect(price - discount, ChatNotifier.minPayable);
  });

  test('one voucher can sit on only one open reservation at a time', () async {
    final c = makeContainer();
    final n = c.read(chatProvider.notifier);
    final a = n.claim('l_ayam');
    final b = n.claim('l_ayam2');
    expect(n.applyVoucher(a, 'PWN-V-3001'), isNull);
    expect(n.applyVoucher(b, 'PWN-V-3001'), 'Voucher sedang dipakai di reservasi lain.');
    n.removeVoucher(a);
    expect(n.applyVoucher(b, 'PWN-V-3001'), isNull, reason: 'free again once the first reservation let go of it');
    await pumpEventQueue();
  });

  test('formatShortDate gives a three-letter Indonesian month', () {
    expect(formatShortDate(DateTime(2026, 11, 18)), '18 Nov 2026');
    expect(formatShortDate(DateTime(2026, 8, 3)), '3 Agu 2026');
  });
}
