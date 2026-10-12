import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/core/data/listings_repository.dart';
import 'package:pawonfood/core/data/pickup_points_repository.dart';
import 'package:pawonfood/core/data/settings_repository.dart';
import 'package:pawonfood/core/models/enums.dart';
import 'package:pawonfood/features/map/map_screen.dart';
import 'package:pawonfood/core/widgets/brand.dart';

import 'support.dart';

/// Flows added with the hi-fi screens: offer sheet, QRIS payment, provider QR, settings, password reset.
void main() {
  setUpAll(loadAppFonts);

  Future<void> openDetail(WidgetTester tester, String name) async {
    final list = find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text(name), 200, scrollable: list);
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('B8e-B8g: the offer sheet checks the amount while typing, then sends offer and note', (tester) async {
    usePhoneScreen(tester);
    await signIn(tester);
    await openDetail(tester, 'Ayam Goreng Lalapan'); // Rp7.000, negotiable
    await tester.tap(find.text('Tulis sendiri'));
    await tester.pumpAndSettle();
    expect(find.text('Tulis tawaranmu'), findsOneWidget);
    expect(tester.widget<InkWell>(find.widgetWithText(InkWell, 'Kirim tawaran')).onTap, isNull);

    final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '8000');
    await tester.pump();
    expect(find.text('Tawaran harus di bawah Rp7.000. Mau harga penuh? Pakai tombol Ambil.'), findsOneWidget);

    await tester.enterText(fields.at(0), '5500');
    await tester.pump();
    expect(find.text('Hemat Rp1.500 dari harga'), findsOneWidget);
    await tester.enterText(fields.at(1), 'Saya bisa ambil sekarang.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Kirim tawaran · Rp5.500'));
    await tester.pumpAndSettle();

    // B10: the simulated provider accepts (half the price or more)
    expect(find.text('Saya bisa ambil sekarang.'), findsOneWidget);
    expect(find.text('Tawaran Rp5.500 diterima'), findsOneWidget);
    expect(find.text('Pilih cara bayar'), findsOneWidget);
  });

  testWidgets('B10d-B10g: QRIS says "belum masuk" first, then the payment succeeds', (tester) async {
    usePhoneScreen(tester);
    await signIn(tester);
    await openDetail(tester, 'Ayam Goreng Lalapan');
    await tester.tap(find.text('Ambil · Rp7.000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih cara bayar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QRIS'));
    await tester.tap(find.textContaining('Saya telah memeriksa kondisi makanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Bayar Rp7.000'));
    await tester.pumpAndSettle();
    expect(find.text('Bayar dengan QRIS'), findsOneWidget);

    await tester.tap(find.text('Cek status pembayaran'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('Pembayaran belum masuk. Kalau sudah bayar, tunggu sebentar lalu cek lagi.'), findsOneWidget);

    await tester.tap(find.text('Cek status pembayaran'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Pembayaran berhasil'), findsOneWidget);

    await tester.tap(find.text('Kembali ke chat'));
    await tester.pumpAndSettle();
    expect(find.text('Lunas'), findsOneWidget);
    expect(find.textContaining('Lunas Rp7.000 via QRIS'), findsOneWidget);
  });

  testWidgets('C17: the provider accepts, shows the QR, and the receiver\'s scan lands on "Makanan terselamatkan!"', (tester) async {
    usePhoneScreen(tester);
    await signIn(tester);
    await tester.tap(find.text('Pesan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saya berbagi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dina Ayu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terima Rp3.000'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Buka QR ambil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka QR ambil'));
    await tester.pumpAndSettle(); // the simulated receiver scans right away in tests
    expect(find.text('Makanan terselamatkan!'), findsOneWidget);
    expect(find.text('+10 poin'), findsOneWidget);
    expect(find.text('Terima Rp3.000 di tempat'), findsOneWidget);
  });

  testWidgets('Pengaturan: the default radius applies to Beranda; deleting the account needs "HAPUS"', (tester) async {
    usePhoneScreen(tester);
    await signIn(tester);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    final list = find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Keluar'), 200, scrollable: list); // past the bottom nav
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Radius default'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 km'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.text('Pengaturan')));
    expect(container.read(settingsProvider).radiusMeters, 2000);
    expect(container.read(radiusMetersProvider), 2000);

    await tester.tap(find.text('Hapus akun'));
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(find.widgetWithText(InkWell, 'Hapus akun').last).onTap, isNull);
    await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)), 'HAPUS');
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Hapus akun').last);
    await tester.pumpAndSettle();
    expect(find.text('Masak kebanyakan? Bagikan, jangan buang.'), findsOneWidget);
  });

  testWidgets('A4c-A4e: forgot password -> 6-digit code -> new password -> back to Masuk', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah punya akun? Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lupa password?'));
    await tester.pumpAndSettle();
    expect(find.text('Lupa password?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'rafi@email.com');
    await tester.tap(find.text('Kirim kode'));
    await tester.pumpAndSettle();
    expect(find.text('Kami kirim kode 6 digit ke r***@email.com.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '482193');
    await tester.pumpAndSettle();
    expect(find.text('Buat password baru'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'rahasia456');
    await tester.enterText(fields.at(1), 'rahasia456');
    await tester.tap(find.text('Simpan password'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk'), findsWidgets);
  });

  testWidgets('B5 "Lihat peta penuh" opens Peta; D17 shows the tier stepper', (tester) async {
    usePhoneScreen(tester);
    await signIn(tester);
    await tester.tap(find.byType(FullscreenIcon));
    await tester.pumpAndSettle();
    expect(find.text('Radius 1 km dari'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Sekarang'), findsOneWidget);
    expect(find.text('Berikutnya'), findsOneWidget);
    expect(find.text('Top Impact'), findsOneWidget);
    expect(find.text('Pawon Hero'), findsOneWidget);
  });

  testWidgets('Beranda and Peta share the same category chips and selection', (tester) async {
    usePhoneScreen(tester);
    await signIn(tester);
    final container = ProviderScope.containerOf(tester.element(find.text('Ready-to-Eat')));
    await tester.tap(find.text('Ready-to-Eat'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Peta'));
    await tester.pumpAndSettle();
    expect(find.text('Ready-to-Eat'), findsOneWidget);
    expect(find.text('Sedang hangat'), findsNothing);
    expect(container.read(mapListingsProvider).every((i) => i.listing.category == FoodCategory.makananMatang), isTrue);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(container.read(categoryFilterProvider), isNull);
  });

  group('saved pickup points', () {
    test('save, make primary and remove', () {
      final c = makeContainer();
      final points = c.read(pickupPointsProvider.notifier);
      expect(points.primary.name, 'Kos Melati, Pogung');
      final saved = points.save(PickupPoint(id: 'x', name: 'Depan kos', address: 'Jl. Pogung Baru No. 14', position: gpsPoint.position, fromMap: true));
      expect(c.read(pickupPointsProvider).length, 3);
      points.makePrimary(saved.id);
      expect(points.primary.id, saved.id);
      points.remove(saved.id);
      expect(c.read(pickupPointsProvider).length, 2);
      expect(c.read(pickupPointsProvider).where((p) => p.primary).length, 1);
    });
  });
}
