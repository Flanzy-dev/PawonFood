import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/data/pickup_points_repository.dart';
import '../../core/models/enums.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/services/food_validator.dart';
import '../../core/services/formatters.dart';
import '../../core/services/pickup_times.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/option_row.dart';
import '../../core/widgets/pills.dart';
import 'pickup_point_sheet.dart';
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
  /// Null until picked when the AI could not tell the category.
  FoodCategory? _category;
  var _portions = 2;
  var _free = false;
  var _negotiable = true;
  late final List<DateTime> _times;
  DateTime? _pickupBy;
  late PickupPoint _point = ref.read(pickupPointsProvider.notifier).primary;
  DateTime? _bestBefore;
  String? _nameError;
  String? _priceError;
  String? _categoryError;
  String? _formError;
  var _published = false;

  @override
  void initState() {
    super.initState();
    final capture = ref.read(shareCaptureProvider);
    _name = TextEditingController(text: capture?.result.suggestedName ?? '');
    _category = capture?.result.category;
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
    if (_published) return; // a second tap during the page transition must not publish twice
    final capture = ref.read(shareCaptureProvider);
    // Only a photo the AI passed (or sent to manual review) can be published; a failed or missing check never can.
    if (capture == null || !capture.result.eligible) {
      setState(() => _formError = 'Foto belum lolos pengecekan AI. Kembali ke kamera untuk foto ulang.');
      return;
    }
    final price = _free ? 0 : parseAmount(_price.text);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Nama makanan wajib diisi' : null;
      _priceError = price == null ? 'Masukkan harga' : null;
      _categoryError = _category == null ? 'Pilih kategori dulu' : null;
      _formError = null;
    });
    if (_nameError != null || _priceError != null || _categoryError != null) return;
    final result = ref.read(listingsProvider.notifier).publish(
          PublishDraft(
            name: _name.text,
            category: _category!,
            aiCategory: capture.result.category,
            portions: _portions,
            price: price!,
            negotiable: !_free && _negotiable,
            pickupBy: _pickupBy ?? _times[1],
            pickupPoint: _point.fromMap ? '${_point.name}, ${_point.address}' : _point.name,
            pickupPosition: _point.position,
            bestBefore: _category == FoodCategory.sealedFood ? _bestBefore : null,
            photoPath: capture.photoPath,
            aiConfidence: capture.result.confidence,
            aiStatus: capture.result.verdict == AiVerdict.approved ? AiStatus.approved : AiStatus.pendingReview,
          ),
        );
    if (result.error != null) {
      setState(() => _formError = result.error);
      return;
    }
    _published = true;
    context.pushReplacement('/share/done/${result.listing!.id}');
  }

  Future<void> _changePoint() async {
    final picked = await showPickupPointSheet(context, current: _point);
    if (picked != null && mounted) setState(() => _point = picked);
  }

  /// C15c "Ubah kategori": three categories; sealed food also asks "Baik digunakan sebelum".
  void _changeCategory() {
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void pick(FoodCategory c) {
            setState(() {
              _category = c;
              _categoryError = null;
            });
            setSheet(() {});
            if (c != FoodCategory.sealedFood) Navigator.of(ctx).pop();
          }

          Future<void> pickDate() async {
            final now = ref.read(clockProvider)();
            final d = await showDatePicker(context: ctx, initialDate: _bestBefore ?? now.add(const Duration(days: 2)), firstDate: now, lastDate: now.add(const Duration(days: 365)));
            if (d == null) return;
            setState(() => _bestBefore = d);
            if (ctx.mounted) Navigator.of(ctx).pop();
          }

          return SheetBody(
            title: 'Ubah kategori',
            children: [
              for (final c in FoodCategory.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OptionRow(title: c.title, subtitle: c.examples, selected: c == _category, onTap: () => pick(c)),
                ),
              AnimatedSize(
                duration: Motion.of(ctx, Motion.base),
                curve: Motion.move,
                child: _category == FoodCategory.sealedFood
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 6),
                        Text('Baik digunakan sebelum', style: AppTypography.display(16, weight: 700)),
                        const SizedBox(height: 8),
                        OptionRow(
                          title: _bestBefore == null ? 'dd/mm/yyyy' : formatLongDate(_bestBefore!),
                          lead: OptionLead.icon,
                          icon: LucideIcons.calendar,
                          selected: false,
                          onTap: pickDate,
                        ),
                      ])
                    : const SizedBox(width: double.infinity),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(shareCaptureProvider);
    final now = ref.watch(clockProvider)();
    final pending = capture?.result.verdict == AiVerdict.pendingReview;
    final checked = capture != null && capture.result.eligible;
    final notes = [...?capture?.result.visibleSigns, ...?capture?.result.warnings];
    // The reason is only worth repeating when it says more than "Foto lolos validasi".
    final reason = pending ? capture?.result.message : null;

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
                                _category == null
                                    ? Pill('Pilih kategori', fill: AppColors.surfaceSand, color: _categoryError == null ? AppColors.ink : AppColors.error, height: 28, size: 13, hPad: 12)
                                    : Pill(_category!.label, fill: AppColors.successTint, color: AppColors.primary, height: 28, size: 13, hPad: 12),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: _changeCategory,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2), child: Text('Ubah', style: AppTypography.text(14, weight: 700, color: AppColors.primary))),
                                ),
                              ]),
                              const SizedBox(height: 2),
                              Row(children: [
                                Icon(!checked ? LucideIcons.triangleAlert : (pending ? LucideIcons.clock : LucideIcons.shieldCheck), size: 18, color: checked ? AppColors.primary : AppColors.error),
                                const SizedBox(width: 6),
                                Flexible(child: Text(!checked ? 'Foto belum dicek AI' : (pending ? 'Menunggu tinjauan manual' : 'Foto lolos validasi'), style: AppTypography.text(13, weight: 600))),
                              ]),
                              if (_categoryError != null) ...[
                                const SizedBox(height: 4),
                                Text(_categoryError!, style: AppTypography.text(13, weight: 600, color: AppColors.error)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (checked && (notes.isNotEmpty || reason != null)) ...[
                    const SizedBox(height: 12),
                    InfoBox(
                      [?reason, if (notes.isNotEmpty) 'Terlihat di foto: ${notes.join('; ')}.', 'Pengecekan foto oleh AI bukan jaminan keamanan pangan.'].join('\n'),
                      title: 'Catatan AI',
                      icon: LucideIcons.scanEye,
                    ),
                  ],
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: '',
                          semanticLabel: 'Harga per porsi',
                          controller: _price,
                          prefix: 'Rp',
                          suffixText: '/porsi',
                          errorText: _priceError,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [ThousandsFormatter()],
                          onChanged: (_) => setState(() => _priceError = null),
                        ),
                        AppCheckbox(
                          value: _negotiable,
                          label: 'Boleh ditawar',
                          textSize: 15,
                          helper: 'Pembeli bisa ajukan harga lewat chat',
                          onChanged: (v) => setState(() => _negotiable = v),
                        ),
                      ],
                    ),
                  // The checkbox row carries its own 10 px of padding, so the gap is shorter after it.
                  SizedBox(height: _free ? 16 : 5),
                  Text('Ambil paling lambat jam', style: AppTypography.display(17, weight: 700)),
                  const SizedBox(height: 8),
                  TimeChips(times: _times, selected: _pickupBy, now: now, onSelected: (t) => setState(() => _pickupBy = t)),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Icon(LucideIcons.mapPin, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FadeSwitch(
                        child: Text('Titik ambil: ${_point.name}', key: ValueKey(_point.id), style: AppTypography.text(13, weight: 500, color: AppColors.inkMuted)),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Ubah titik ambil',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: _changePoint,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), child: Text('Ubah', style: AppTypography.text(14, weight: 700, color: AppColors.primary))),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          StickyBottomBar(
            compact: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A blocking error sits right above the button, where the tap happened: at the end of the list it
                // could be scrolled out of view.
                if (_formError != null) ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 1), child: Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.error)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_formError!, style: AppTypography.text(13, weight: 600, color: AppColors.error))),
                  ]),
                  const SizedBox(height: 10),
                ],
                // The bar follows the text: one line on a wide phone, two on a narrow one (the Figma frame shows two). The space
                // above (8, from StickyBottomBar) and between text and button (14) stays fixed: the text sits close to the bar's top line.
                // Hidden while the keyboard is up: it would eat the form's visible area on a short phone.
                if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                  Text('Dengan membagikan, kamu menjamin makanan ini masih layak makan.', textAlign: TextAlign.center, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
                  const SizedBox(height: 14),
                ],
                AppButton(label: 'Bagikan sekarang', onPressed: _publish),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
