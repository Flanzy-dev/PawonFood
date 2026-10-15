import 'package:latlong2/latlong.dart';

import '../models/listing.dart';
import 'formatters.dart';
import 'geo.dart';
import 'pickup_times.dart';

/// The delivery fees a provider can pick in the share form (PRD Handover methods). All of it goes to the provider.
const deliveryFeeOptions = [0, 2000, 3000];

/// Input validation (AGENTS.md: price >= 0, portions >= 1, pickup time in the future). Messages are Indonesian.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _phone = RegExp(r'^(\+62|62|0)8\d{8,11}$');

  static String? name(String? v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null;

  static String? emailOrPhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email atau nomor HP wajib diisi';
    final phone = s.replaceAll(RegExp(r'[\s-]'), '');
    return _email.hasMatch(s) || _phone.hasMatch(phone) ? null : 'Format email atau nomor HP tidak valid';
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'Password minimal 8 karakter';
    if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) return 'Gunakan huruf dan angka';
    return null;
  }

  /// A new password must pass [password] and differ from the old one (A4e, D18i).
  static String? newPassword(String? v, {String? old}) => password(v) ?? (old != null && v == old ? 'Password baru harus berbeda dari yang lama' : null);

  static String? price(int? v) => (v == null || v < 0) ? 'Harga tidak boleh negatif' : null;

  static String? portions(int? v) => (v == null || v < 1) ? 'Minimal 1 porsi' : null;

  static String? pickupTime(DateTime? t, DateTime now) => (t == null || !t.isAfter(now)) ? 'Jam ambil harus di masa depan' : null;

  /// The provider's own deadline ("Atur jam") must be 30 minutes to 6 hours from now (PRD Core Feature 2, Proposed).
  static String? pickupWindow(DateTime t, DateTime now) {
    if (t.isBefore(pickupEarliest(now))) return 'Terlalu cepat. Minimal ${formatTime(pickupEarliest(now))} (30 menit lagi)';
    if (t.isAfter(pickupLatest(now))) return 'Terlalu lama. Maksimal ${formatTime(pickupLatest(now))} (6 jam lagi)';
    return null;
  }

  /// An offer must be above Rp0 and below the listed price; the full price goes through "Ambil" (PRD Core Feature 3).
  static String? offerAmount(int? amount, int price) {
    if (amount == null || amount <= 0) return 'Masukkan nominal tawaran';
    if (amount >= price) return 'Tawaran harus di bawah ${formatRupiah(price)}. Mau harga penuh? Pakai tombol Ambil.';
    return null;
  }

  /// The provider's delivery fee: none (pickup only) or one of [deliveryFeeOptions].
  static String? deliveryFee(int? fee) => fee == null || deliveryFeeOptions.contains(fee) ? null : 'Pilih ongkir Rp0, Rp2.000 atau Rp3.000';

  /// "Minta diantar" needs a provider who opened delivery and an address within 1 km of the food.
  static String? delivery(Listing l, LatLng to) {
    if (!l.canDeliver) return 'Penyedia belum membuka opsi antar.';
    if (distanceMeters(l.position, to) > walkableRadiusMeters) return 'Alamatmu lebih dari 1 km dari penyedia.';
    return null;
  }

  /// The share form needs at least one way to hand the food over: "Ambil di tempat" or "Bisa diantar".
  static String? handover(bool allowsPickup, int? deliveryFee) => allowsPickup || deliveryFee != null ? null : 'Pilih minimal satu cara serah terima.';

  /// A receiver's request: pickup ([to] null) when the provider allows it, or delivery to [to] (see [delivery]).
  static String? handoverRequest(Listing l, LatLng? to) {
    if (to == null) return l.allowsPickup ? null : 'Makanan ini hanya bisa diantar.';
    return delivery(l, to);
  }
}
