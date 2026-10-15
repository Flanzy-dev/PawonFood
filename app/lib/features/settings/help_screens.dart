import 'package:flutter/material.dart';

import '../../core/motion/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/settings_list.dart';
import '../../core/widgets/top_bar.dart';

/// Support address shown in Pusat bantuan. The team still has to pick one: set it with
/// `--dart-define=PAWON_SUPPORT_EMAIL=...`, otherwise the Figma placeholder shows.
const supportEmail = String.fromEnvironment('PAWON_SUPPORT_EMAIL', defaultValue: '[EMAIL TIM]');

/// "Terakhir diperbarui" on the legal pages.
const legalUpdated = '7 Oktober 2026';

const _faq = [
  ('Cara membagikan makanan', 'Ketuk tombol Bagikan, foto makanan langsung dengan kamera, cek isian yang sudah diisi AI, lalu ketuk "Bagikan sekarang".'),
  ('Cara menawar dan mengambil', 'Buka makanan, pilih "Tawar cepat" atau "Tulis sendiri". Setelah tawaran diterima, porsi direservasi sampai batas waktu ambil.'),
  ('Cara memindai QR ambil', 'Di titik ambil, minta penyedia membuka QR ambil, lalu ketuk "Pindai QR" di chat. QR hanya berlaku sampai batas waktu ambil.'),
  ('Bisa minta diantar?', 'Bisa, kalau penyedia membuka opsi antar. Di halaman makanan, pilih "Minta diantar" sebelum ketuk Ambil. Alamatnya harus dalam 1 km, dan ongkirnya seluruhnya untuk penyedia. Pindai QR saat makanan sampai.'),
  ('Kenapa fotoku ditolak AI?', 'AI menolak foto yang bukan makanan, foto layar, atau foto yang terlalu gelap. Ambil foto ulang dengan cahaya cukup.'),
  ('Cara melapor makanan atau penyedia', 'Beri ulasan setelah mengambil. Ulasan buruk berulang membuat penyedia di-suspend dulu, lalu diblokir jika berlanjut.'),
];

/// D18k Pusat bantuan: searchable FAQ that opens in place, plus a contact card.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = [for (final f in _faq) if (q.isEmpty || '${f.$1} ${f.$2}'.toLowerCase().contains(q)) f];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: 'Pusat bantuan', fallback: '/settings'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                SearchField(hint: 'Cari bantuan...', onChanged: (v) => setState(() => _query = v)),
                const SizedBox(height: 18),
                if (items.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Belum ada jawaban untuk "$_query".', style: AppTypography.bodyMuted)))
                else
                  SettingsGroup(title: 'Pertanyaan populer', children: [for (final f in items) ExpandableRow(title: f.$1, body: f.$2)]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Masih butuh bantuan?', style: AppTypography.display(17, weight: 700)),
                      const SizedBox(height: 4),
                      Text('Tulis ke $supportEmail, kami bantu secepatnya.', style: AppTypography.text(14, color: AppColors.inkMuted)),
                      const SizedBox(height: 16),
                      AppButton(label: 'Hubungi tim PawonFood', variant: AppButtonVariant.outline, onPressed: () => showAppSnack(context, 'Kirim email ke $supportEmail.')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// D18l Syarat & Ketentuan and D18m Kebijakan Privasi: numbered sections.
class DocScreen extends StatelessWidget {
  const DocScreen.terms({super.key})
      : title = 'Syarat & Ketentuan',
        sections = const [
          ('1. Tentang PawonFood', 'PawonFood adalah perantara yang mempertemukan penyedia dan penerima makanan. PawonFood bukan produsen makanan.'),
          ('2. Kewajiban penyedia', 'Penyedia menjamin makanan masih layak makan dan memotretnya langsung dengan kamera. Foto dari galeri atau internet tidak diterima.'),
          ('3. Kewajiban penerima', 'Penerima memeriksa kondisi makanan sebelum mengambil dan membebaskan PawonFood dari tuntutan kesehatan.'),
          ('4. Pembayaran', 'Ambil dengan memindai QR di HP penyedia sebelum batas waktu ambil, lalu bayar tunai di tempat atau lewat QRIS di aplikasi. Jangan transfer uang di luar aplikasi sebelum makanan kamu terima.'),
          ('5. Ulasan dan sanksi penyedia', 'Penerima menilai makanan setelah diambil. Penyedia dengan ulasan buruk berulang akan di-suspend dulu, lalu diblokir jika berlanjut.'),
        ];

  const DocScreen.privacy({super.key})
      : title = 'Kebijakan Privasi',
        sections = const [
          ('1. Data yang kami kumpulkan', 'Nama, email atau nomor HP, titik ambil, dan foto makanan yang kamu ambil langsung dengan kamera.'),
          ('2. Cara kami memakainya', 'Untuk menampilkan makanan di dekatmu, menghubungkan chat dan QR ambil, serta menghitung poin dan ulasan.'),
          ('3. Lokasi dan izin GPS', 'Lokasi dipakai saat aplikasi dibuka untuk menghitung jarak. Kamu bisa menolak izin dan memilih lokasi manual.'),
          ('4. Berbagi dengan pihak lain', 'Sebelum reservasi diterima, penerima hanya melihat area dan jarak. Alamat lengkap titik ambil tampil setelah reservasi diterima. Data tidak dijual.'),
          ('5. Hak kamu', 'Kamu bisa menghapus akun kapan saja lewat Pengaturan. Data akun dan riwayat ikut dihapus.'),
        ];

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: EntranceScope(
            child: Column(children: [
              TopBar(title: title, fallback: '/settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Text('Terakhir diperbarui $legalUpdated', style: AppTypography.text(13, color: AppColors.inkMuted)),
                    for (final (i, s) in sections.indexed)
                      FadeSlideIn(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.$1, style: AppTypography.display(18, weight: 700, height: 24)),
                            const SizedBox(height: 6),
                            Text(s.$2, style: AppTypography.text(15, height: 22, color: AppColors.inkMuted)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}
