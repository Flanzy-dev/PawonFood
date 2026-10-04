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

  static String? price(int? v) => (v == null || v < 0) ? 'Harga tidak boleh negatif' : null;

  static String? portions(int? v) => (v == null || v < 1) ? 'Minimal 1 porsi' : null;

  static String? pickupTime(DateTime? t, DateTime now) => (t == null || !t.isAfter(now)) ? 'Jam ambil harus di masa depan' : null;

  static String? offerAmount(int? amount, int price) {
    if (amount == null || amount <= 0) return 'Masukkan nominal tawaran';
    if (amount > price) return 'Tawaran tidak boleh melebihi harga';
    return null;
  }
}
