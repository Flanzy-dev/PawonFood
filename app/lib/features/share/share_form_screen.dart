import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/data/session_repository.dart';
import '../../core/models/enums.dart';
import '../../core/services/food_validator.dart';
import '../../core/services/pickup_times.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/pills.dart';
import 'share_state.dart';

/// Step 2 of 3 (C15): "Semua sudah diisi. Cek sebentar, lalu bagikan." Everything is pre-filled by the AI result.
class ShareFormScreen extends ConsumerStatefulWidget {
  const ShareFormScreen({super.key});

  @override
  ConsumerState<ShareFormScreen> createState() => _ShareFormScreenState();
}

class _ShareFormScreenState extends ConsumerState<ShareFormScreen> {
  late final TextEditingController _name;
  final _price = TextEditingController(text: '5.000');
  late FoodCategory _category;
  var _portions = 2;
  var _free = false;
  var _negotiable = true;
  late final List<DateTime> _times;
  DateTime? _pickupBy;
  String? _nameError;
  String? _priceError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final capture = ref.read(shareCaptureProvider);
    _name = TextEditingController(text: capture?.result.suggestedName ?? '');
    _category = capture?.result.category ?? FoodCategory.makananMatang;
    _times = suggestPickupTimes(ref.read(clockProvider)());
    _pickupBy = _times[1];
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _publish() {
    final capture = ref.read(shareCaptureProvider);
    final user = ref.read(sessionProvider);
    final price = _free ? 0 : parseAmount(_price.text);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Nama makanan wajib diisi' : null;
      _priceError = price == null ? 'Masukkan harga' : null;
      _formError = null;
    });
    if (_nameError != null || _priceError != null) return;
    final result = ref.read(listingsProvider.notifier).publish(
          PublishDraft(
            name: _name.text,
            category: _category,
            portions: _portions,
            price: price!,
            negotiable: !_free && _negotiable,
            pickupBy: _pickupBy ?? _times[1],
            pickupPoint: user?.pickupPoint ?? 'Kos Melati, Pogung',
            photoPath: capture?.photoPath,
            aiConfidence: capture?.result.confidence ?? 0,
            aiStatus: capture?.result.verdict == AiVerdict.pendingReview ? AiStatus.pendingReview : AiStatus.approved,
          ),
        );
    if (result.error != null) {
      setState(() => _formError = result.error);
      return;
    }
    context.pushReplacement('/share/done/${result.listing!.id}');
  }

  void _changeCategory() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ubah kategori', style: AppTypography.titleL),
              const SizedBox(height: 8),
              for (final c in FoodCategory.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 52,
                  title: Text(c.label, style: AppTypography.text(16, weight: c == _category ? 700 : 500)),
                  trailing: c == _category ? const Icon(LucideIcons.check, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() => _category = c);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(shareCaptureProvider);
    final pickupPoint = ref.watch(sessionProvider.select((u) => u?.pickupPoint)) ?? 'Kos Melati, Pogung';
    final now = ref.watch(clockProvider)();
    final pending = capture?.result.verdict == AiVerdict.pendingReview;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(children: [
                    RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali ke kamera', onTap: () => context.canPop() ? context.pop() : context.go('/')),
                    Expanded(child: Text('Langkah 2 dari 3', textAlign: TextAlign.center, style: AppTypography.text(17, weight: 700))),
                    const SizedBox(width: 44),
                  ]),
                  const SizedBox(height: 10),
                  const StepProgress(current: 2),
                  const SizedBox(height: 16),
                  Text('Semua sudah diisi. Cek sebentar, lalu bagikan.', style: AppTypography.display(24, height: 29)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: capture == null
                                ? const ColoredBox(color: AppColors.foodWarm)
                                : Image.file(File(capture.photoPath), fit: BoxFit.cover, cacheWidth: 240, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.foodWarm)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kategori, diisi otomatis oleh AI', style: AppTypography.text(13, color: AppColors.inkMuted)),
                              const SizedBox(height: 6),
                              Row(children: [
                                Pill(_category.label, fill: AppColors.successTint, color: AppColors.primary, height: 28, size: 13, hPad: 12),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: _changeCategory,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2), child: Text('Ubah', style: AppTypography.text(14, weight: 700, color: AppColors.primary).copyWith(decoration: TextDecoration.underline))),
                                ),
                              ]),
                              const SizedBox(height: 2),
                              Row(children: [
                                Icon(pending ? LucideIcons.clock : LucideIcons.shieldCheck, size: 18, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Flexible(child: Text(pending ? 'Menunggu tinjauan manual' : 'Foto lolos validasi', style: AppTypography.text(13, weight: 600))),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(label: 'Nama makanan', controller: _name, errorText: _nameError, hint: 'Contoh: Ayam goreng', textCapitalization: TextCapitalization.sentences, onChanged: (_) => setState(() => _nameError = null)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Text('Sisa berapa porsi?', style: AppTypography.display(17, weight: 700))),
                    QtyStepper(value: _portions, max: 50, onChanged: (v) => setState(() => _portions = v)),
                  ]),
                  const SizedBox(height: 16),
                  Text('Mau dibagikan bagaimana?', style: AppTypography.display(17, weight: 700)),
                  const SizedBox(height: 8),
                  SegmentedControl(options: const ['Gratis', 'Jual murah'], selected: _free ? 0 : 1, onChanged: (i) => setState(() => _free = i == 0)),
                  const SizedBox(height: 12),
                  if (_free)
                    Row(children: [
                      const Icon(LucideIcons.coins, size: 18, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Makanan gratis memberi poin lebih banyak.', style: AppTypography.text(14, color: AppColors.inkMuted))),
                    ])
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: AppTextField(
                            label: '',
                            controller: _price,
                            prefix: 'Rp',
                            suffixText: '/porsi',
                            errorText: _priceError,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [ThousandsFormatter()],
                            onChanged: (_) => setState(() => _priceError = null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: AppCheckbox(value: _negotiable, label: 'Boleh ditawar', textSize: 13, onChanged: (v) => setState(() => _negotiable = v))),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Text('Ambil paling lambat jam', style: AppTypography.display(17, weight: 700)),
                  const SizedBox(height: 8),
                  TimeChips(times: _times, selected: _pickupBy, now: now, onSelected: (t) => setState(() => _pickupBy = t)),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Icon(LucideIcons.mapPin, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Titik ambil: $pickupPoint · dari profil', style: AppTypography.text(13, weight: 500, color: AppColors.inkMuted))),
                  ]),
                  if (_formError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(children: [
                        const Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.error),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_formError!, style: AppTypography.text(13, weight: 600, color: AppColors.error))),
                      ]),
                    ),
                ],
              ),
            ),
          ),
          StickyBottomBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Dengan membagikan, kamu menjamin makanan ini masih layak makan.', textAlign: TextAlign.center, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
                const SizedBox(height: 12),
                AppButton(label: 'Bagikan sekarang', onPressed: _publish),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
