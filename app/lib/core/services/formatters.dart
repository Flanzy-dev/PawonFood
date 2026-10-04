/// Indonesian formatting helpers. Prices: `Rp5.000`, times: `20.30`, distance: `300 m`.
String formatRupiah(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${value < 0 ? '-' : ''}Rp$buf';
}

/// `20.30` (dot separator, 24 hour).
String formatTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

String formatDistance(double meters) {
  if (meters < 1000) return '${(meters / 10).round() * 10} m'; // rounded to 10 m: 296 -> "300 m"
  return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Walking speed ~80 m/min, never below 1 minute.
int walkMinutes(double meters) => (meters / 80).ceil().clamp(1, 999);

String walkLabel(double meters) => '± ${walkMinutes(meters)} mnt jalan kaki';

/// Time label for a thread row: `19.42` today, `Kemarin`, or `3 Okt`.
String formatThreadTime(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return formatTime(at);
  if (diff == 1) return 'Kemarin';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return '${at.day} ${months[at.month - 1]}';
}

/// "hari ini" or "besok" for a pickup deadline that may pass midnight.
String dayCaption(DateTime at, DateTime now) {
  final days = DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  return days <= 0 ? 'hari ini' : (days == 1 ? 'besok' : '$days hari lagi');
}

/// `Hari ini` / `Kemarin` / date for the chat day separator.
String formatDayLabel(DateTime at, DateTime now) {
  final label = formatThreadTime(at, now);
  return RegExp(r'^\d{2}\.\d{2}$').hasMatch(label) ? 'Hari ini' : label;
}

/// Drops a leading venue word: "Warteg Bu Siti" -> "Bu Siti", "Katering Ibu Ani" -> "Ibu Ani".
String shortName(String name) {
  final parts = name.split(' ');
  const venues = {'Warteg', 'Warung', 'Warmindo', 'Katering', 'Kos'};
  return parts.length > 1 && venues.contains(parts.first) ? parts.skip(1).join(' ') : name;
}

/// `4,8` (comma decimal).
String formatRating(double r) => r.toStringAsFixed(1).replaceAll('.', ',');

String formatKg(double kg) => '${kg.toStringAsFixed(1).replaceAll('.', ',')} kg'.replaceFirst(',0 kg', ' kg');

/// `3 November 2026` (full month name, no zero padding).
String formatLongDate(DateTime d) {
  const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
