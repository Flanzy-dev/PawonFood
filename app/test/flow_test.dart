import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawonfood/core/theme/app_theme.dart';
import 'package:pawonfood/core/widgets/brand_icons.dart';
import 'package:pawonfood/core/widgets/mini_food_card.dart';
import 'package:pawonfood/features/share/share_done_screen.dart';

import 'support.dart';

/// The core receiver journey through the real UI: login -> feed -> detail -> take -> pay -> scan QR -> review -> ad.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('receiver journey from login to review', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    // A1 Welcome -> A4 Masuk
    expect(find.text('Masak kebanyakan? Bagikan, jangan buang.'), findsOneWidget);
    await tester.tap(find.text('Sudah punya akun? Masuk'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'rafi@email.com');
    await tester.enterText(fields.at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(InkWell, 'Masuk'));
    await tester.pumpAndSettle();

    // B5 Beranda
    expect(find.text('Lapar? Masih ada yang hangat di dekatmu.'), findsOneWidget);
    expect(find.text('Pogung, Sleman'), findsOneWidget);
    expect(find.text('150 Poin'), findsOneWidget);
    expect(find.text('Pilihan untukmu di sekitar'), findsOneWidget);

    // B8 Detail
    final list = find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Ayam Goreng Lalapan'), 200, scrollable: list);
    await tester.ensureVisible(find.text('Ayam Goreng Lalapan')); // clear of the tab bar
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayam Goreng Lalapan'));
    await tester.pumpAndSettle();
    expect(find.text('Tawar cepat'), findsOneWidget);
    expect(find.text('Rp4.000'), findsOneWidget);
    expect(find.text('Rp5.500'), findsOneWidget);
    expect(find.text('Deskripsi'), findsOneWidget);
    await tester.tap(find.text('Ambil · Rp7.000'));
    await tester.pumpAndSettle();

    // B10 Chat: reserved, the receiver picks how to pay
    expect(find.text('Ambil Rp7.000 disetujui'), findsOneWidget);
    await tester.tap(find.text('Pilih cara bayar'));
    await tester.pumpAndSettle();

    // B10d Pembayaran: the button stays off until the food-condition consent is checked
    expect(find.text('Rincian'), findsOneWidget);
    expect(tester.widget<InkWell>(find.widgetWithText(InkWell, 'Pakai tunai di tempat')).onTap, isNull);
    await tester.tap(find.textContaining('Saya telah memeriksa kondisi makanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Pakai tunai di tempat'));
    await tester.pumpAndSettle();

    // Back in the chat: scan the provider's QR (decoding is simulated)
    expect(find.textContaining('Bayar Rp7.000 tunai di tempat'), findsOneWidget);
    await tester.tap(find.text('Pindai QR'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // B11 Ulasan
    expect(find.text('Bagaimana makanannya?'), findsOneWidget);
    expect(tester.widget<InkWell>(find.widgetWithText(InkWell, 'Kirim ulasan')).onTap, isNull);
    await tester.tap(find.bySemanticsLabel('4 bintang'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pengambilan berhasil'), findsOneWidget);
    await tester.tap(find.widgetWithText(InkWell, 'Kirim ulasan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // not pumpAndSettle: the video ad would play to the end

    // B11b/B11c: one full-screen ad, closable after 5 seconds
    expect(find.text('Iklan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.tap(find.textContaining(RegExp(r'^(Tutup|Lewati)$')));
    await tester.pumpAndSettle();

    // Back on Beranda (scroll position is kept); the listing now has one portion less (3 -> 2)
    expect(find.text('Ayam Goreng Lalapan'), findsOneWidget);
    expect(find.text('Sisa 2 porsi'), findsWidgets);
  });

  testWidgets('empty state: no listing within 1 km, expand the radius to 2 km', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah punya akun? Masuk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'rafi@email.com');
    await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
    await tester.tap(find.widgetWithText(InkWell, 'Masuk'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pogung, Sleman'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Condongcatur, Sleman'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada makanan di radius 1 km'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300)); // the CTA starts below the fold in the test font
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perluas radius ke 2 km'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada makanan di radius 2 km'), findsNothing);
    expect(find.text('Sayur Lodeh Katering'), findsOneWidget);
  });

  testWidgets('login: social buttons show their logos and the password toggle swaps the eye icon', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah punya akun? Masuk'));
    await tester.pumpAndSettle();
    expect(find.byType(GoogleLogo), findsOneWidget);
    expect(find.byType(AppleLogo), findsOneWidget);
    expect(find.byType(FluentEyeOffIcon), findsOneWidget); // hidden by default
    await tester.tap(find.byTooltip('Tampilkan password'));
    await tester.pumpAndSettle();
    expect(find.byType(FluentEyeIcon), findsOneWidget);
    expect(find.byType(FluentEyeOffIcon), findsNothing);
  });

  testWidgets('Beranda "Semua" opens the full list, which can be re-sorted', (tester) async {
    usePhoneScreen(tester);
    await signIn(tester);
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    expect(find.textContaining('makanan dalam 1 km'), findsOneWidget);
    expect(find.text('Rekomendasi'), findsOneWidget);
    await tester.tap(find.text('Rekomendasi'));
    await tester.pumpAndSettle();
    expect(find.text('Urutkan'), findsOneWidget);
    await tester.tap(find.text('Segera habis'));
    await tester.pumpAndSettle();
    expect(find.text('Rekomendasi'), findsNothing);
    expect(find.text('Segera habis'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Lapar? Masih ada yang hangat di dekatmu.'), findsOneWidget);
  });

  testWidgets('Peta lists the food cards in a draggable sheet', (tester) async {
    usePhoneScreen(tester);
    await signIn(tester);
    await tester.tap(find.text('Peta'));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(MiniFoodCard), findsWidgets);
    expect(find.textContaining('makanan dalam'), findsNothing); // collapsed: no title yet
    await tester.drag(find.byType(MiniFoodCard).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(find.textContaining('makanan dalam'), findsOneWidget);
  });

  testWidgets('claiming a reward: Profil -> Tukar poin -> detail -> confirm -> code', (tester) async {
    usePhoneScreen(tester);
    await signIn(tester);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat semua'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo kamu'), findsOneWidget);

    // Not enough points: 200 > 150
    await tester.tap(find.text('Voucher belanja minimarket'));
    await tester.pumpAndSettle();
    expect(find.text('Kurang 50 poin lagi untuk klaim voucher ini'), findsOneWidget);
    expect(find.text('Poin belum cukup'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();

    // Enough points: 150
    await tester.tap(find.text('Diskon layanan antar'));
    await tester.pumpAndSettle();
    expect(find.text('Klaim voucher · 150 poin'), findsOneWidget);
    await tester.tap(find.text('Klaim voucher · 150 poin'));
    await tester.pumpAndSettle();
    expect(find.text('Klaim voucher ini?'), findsOneWidget);
    expect(find.text('0 poin'), findsOneWidget); // sisa poin
    await tester.tap(find.text('Klaim sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Voucher berhasil diklaim!'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^PWN-V-\d{4}$')), findsOneWidget);
    expect(find.textContaining('sisa poin kamu 0'), findsOneWidget);
    await tester.tap(find.text('Kembali ke Profil'));
    await tester.pumpAndSettle();
    expect(find.text('0 Poin'), findsOneWidget);
  });

  testWidgets('C16 shows only the success message and one Kembali button', (tester) async {
    usePhoneScreen(tester);
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const ShareDoneScreen(listingId: 'l_ayam'))]);
    await tester.pumpWidget(ProviderScope(overrides: testOverrides(), child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('Makananmu sudah tayang!'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text('Lihat di peta'), findsNothing);
    expect(find.text('Bagikan lagi'), findsNothing);
    expect(find.textContaining('Kamu dapat poin'), findsOneWidget);
  });
}
