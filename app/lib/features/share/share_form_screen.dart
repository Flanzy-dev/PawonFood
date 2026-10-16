import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/listings_repository.dart';
import '../../core/data/providers.dart';
import '../../core/data/pickup_points_repository.dart';
import '../../core/models/enums.dart';
import '../../core/models/recipe.dart';
import '../../core/motion/entrance.dart';
import '../../core/motion/motion.dart';
import '../../core/services/food_validator.dart';
import '../../core/services/formatters.dart';
import '../../core/services/pickup_times.dart';
import '../../core/services/recipe_ideas.dart';
import '../../core/services/recipe_matcher.dart';
import '../../core/services/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/info_box.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/option_row.dart';
import '../../core/widgets/pickup_time_sheet.dart';
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
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController(text: '5.000');

  /// Fields the provider changed by hand. The AI answer arrives in the background and only fills the rest.
  var _nameEdited = false;
  var _descriptionEdited = false;
  var _categoryEdited = false;
  var _tagsEdited = false;
  /// Null until picked when the AI could not tell the category.
  FoodCategory? _category;
  var _portions = 2;

  /// "Kemasan". Sealed food is always wrapped, so the control is hidden for it ([_packagingNow]).
  var _packaging = Packaging.dibungkus;
  Packaging get _packagingNow => _category == FoodCategory.sealedFood ? Packaging.dibungkus : _packaging;
  var _free = false;
  var _negotiable = true;

  /// "Cara serah terima": "Ambil di tempat" (on by default), and "Bisa diantar (< 1 km)" with the fee the provider picks.
  /// Delivery is off by default, so pickup alone keeps the 3 taps. At least one must stay on.
  var _pickup = true;
  var _delivery = false;
  var _deliveryFee = 2000;
  late final List<DateTime> _times;
  DateTime? _pickupBy;

  /// The deadline picked with "Atur jam" (shown on the fourth chip).
  DateTime? _customPickup;
  late PickupPoint _point = ref.read(pickupPointsProvider.notifier).primary;
  DateTime? _bestBefore;
  String? _nameError;
  String? _priceError;
  String? _categoryError;
  String? _formError;
  var _published = false;

  /// "Pilihan sehat": pre-selected from what the AI saw, then confirmed by the provider.
  final _healthTags = <HealthTag>{};

  /// "Ide resep" (fresh ingredients only): the attached recipe, and ideas asked from the AI.
  Recipe? _recipe;
  var _aiRecipes = <Recipe>[];
  var _askingAi = false;

  @override
  void initState() {
    super.initState();
    _fillFromAi(ref.read(shareCaptureProvider));
    _times = suggestPickupTimes(ref.read(clockProvider)());
    _pickupBy = _times[1];
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Pre-fills name, description, category and health tags from the AI answer, except what the provider already set.
  /// A rejected photo fills nothing: the provider has to retake it.
  void _fillFromAi(ShareCapture? capture) {
    final r = capture?.result;
    if (r == null || !r.eligible) return;
    if (!_nameEdited && r.suggestedName != null) _name.text = r.suggestedName!;
    if (!_descriptionEdited && r.suggestedDescription != null) _description.text = r.suggestedDescription!;
    if (!_categoryEdited) _category = r.category;
    if (!_tagsEdited) {
      _healthTags
        ..clear()
        ..addAll(r.suggestedHealthTags);
    }
  }

  /// "Atur jam": a time picker for the latest pickup time (30 minutes to 6 hours from now).
  Future<void> _pickCustomTime() async {
    final t = await showPickupTimeSheet(context, now: ref.read(clockProvider)(), initial: _customPickup ?? _pickupBy);
    if (t != null && mounted) {
      setState(() {
        _customPickup = t;
        _pickupBy = t;
      });
    }
  }

  void _publish() {
    if (_published) return; // a second tap during the page transition must not publish twice
    final capture = ref.read(shareCaptureProvider);
    if (capture != null && capture.checking) {
      setState(() => _formError = 'AI masih memeriksa foto. Tunggu sebentar, lalu bagikan.');
      return;
    }
    // Only a photo the AI passed (or sent to manual review) can be published; a failed or missing check never can.
    if (capture == null || !capture.eligible) {
      setState(() => _formError = 'Foto belum lolos pengecekan AI. Kembali ke kamera untuk foto ulang.');
      return;
    }
    final aiResult = capture.result!;
    final price = _free ? 0 : parseAmount(_price.text);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Nama makanan wajib diisi' : null;
      _priceError = price == null ? 'Masukkan harga' : null;
      _categoryError = _category == null ? 'Pilih kategori dulu' : null;
      _formError = null;
    });
    if (_nameError != null || _priceError != null || _categoryError != null) return;
    // A deadline picked with "Atur jam" must stay inside the allowed window (the quick chips always do).
    final deadlineError = _customPickup != null && _pickupBy == _customPickup ? Validators.pickupWindow(_customPickup!, ref.read(clockProvider)()) : null;
    if (deadlineError != null) {
      setState(() => _formError = deadlineError);
      return;
    }
    final result = ref.read(listingsProvider.notifier).publish(
          PublishDraft(
            name: _name.text,
            category: _category!,
            description: _description.text.trim().isEmpty ? null : _description.text.trim(),
            aiCategory: aiResult.category,
            portions: _portions,
            price: price!,
            negotiable: !_free && _negotiable,
            pickupBy: _pickupBy ?? _times[1],
            pickupPoint: _point.fromMap ? '${_point.name}, ${_point.address}' : _point.name,
            pickupPosition: _point.position,
            bestBefore: _category == FoodCategory.sealedFood ? _bestBefore : null,
            healthTags: _healthTags,
            recipe: _category == FoodCategory.bahanMentah ? _recipe : null,
            deliveryFee: _delivery ? _deliveryFee : null,
            allowsPickup: _pickup,
            packaging: _packagingNow,
            photoPath: capture.photoPath,
            aiConfidence: aiResult.confidence,
            aiStatus: aiResult.verdict == AiVerdict.approved ? AiStatus.approved : AiStatus.pendingReview,
          ),
        );
    if (result.error != null) {
      setState(() => _formError = result.error);
      return;
    }
    _published = true;
    context.pushReplacement('/share/done/${result.listing!.id}');
  }

  /// "Minta ide dari AI": asks the server for recipe ideas for the typed ingredients; the local list stays on failure.
  Future<void> _askAi() async {
    final ideas = ref.read(recipeIdeasProvider);
    final text = _name.text.trim();
    if (ideas == null || _askingAi) return;
    if (text.length < 2) {
      setState(() => _nameError = 'Isi nama bahan dulu');
      return;
    }
    setState(() => _askingAi = true);
    try {
      final found = await ideas.suggest(text);
      if (!mounted) return;
      setState(() => _aiRecipes = found);
      if (found.isEmpty) _snack('AI belum punya ide untuk bahan ini.');
    } on RecipeIdeasUnavailable {
      if (mounted) _snack('Ide resep dari AI belum bisa dimuat.');
    } finally {
      if (mounted) setState(() => _askingAi = false);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

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
              _categoryEdited = true;
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

  /// "Ide resep": recipes that use the typed ingredients; the provider can attach one for the receiver.
  Widget _recipeSection() {
    final library = ref.watch(recipesProvider);
    final local = suggestRecipes(_name.text, library);
    final options = [
      for (final m in local) (m.recipe, 'cocok: ${m.matched.join(', ')}'),
      for (final r in _aiRecipes) (r, 'Ide AI'),
    ];
    // An attached recipe stays listed even after the name changed and it no longer matches.
    if (_recipe != null && options.every((o) => o.$1.id != _recipe!.id)) options.insert(0, (_recipe!, 'dipilih'));
    final canAskAi = ref.watch(recipeIdeasProvider) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Ide resep', style: AppTypography.display(17, weight: 700)),
        const SizedBox(height: 4),
        Text('Resep yang kamu pilih ditandai Diverifikasi pemberi. Tanpa pilihan, penerima tetap melihat saran otomatis yang belum diverifikasi.', style: AppTypography.text(13, color: AppColors.inkMuted)),
        const SizedBox(height: 10),
        if (options.isEmpty)
          Text('Belum ada resep yang cocok.', style: AppTypography.text(14, color: AppColors.inkMuted))
        else
          for (final (r, why) in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OptionRow(
                title: r.title,
                subtitle: '${r.minutes} mnt · $why',
                lead: OptionLead.icon,
                icon: LucideIcons.chefHat,
                showCheck: true,
                selected: _recipe?.id == r.id,
                onTap: () => setState(() => _recipe = _recipe?.id == r.id ? null : r),
              ),
            ),
        if (canAskAi)
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(label: _askingAi ? 'Mencari ide...' : 'Minta ide dari AI', variant: AppButtonVariant.outline, expand: false, onPressed: _askingAi ? null : _askAi),
          ),
      ],
    );
  }

  /// The AI line in the photo card: running, passed, waiting for review, or a photo that cannot be shared.
  Widget _aiStatus(ShareCapture? capture) {
    final (IconData? icon, String text, Color color) = switch (capture) {
      null => (LucideIcons.triangleAlert, 'Foto belum dicek AI', AppColors.error),
      ShareCapture(checking: true) => (null, 'AI sedang mengenali makanan...', AppColors.inkMuted),
      ShareCapture(failure: != null) => (LucideIcons.wifiOff, 'Pemeriksaan AI gagal', AppColors.error),
      ShareCapture(eligible: false) => (LucideIcons.triangleAlert, 'Foto belum lolos', AppColors.error),
      ShareCapture(result: ValidationResult(verdict: AiVerdict.pendingReview)) => (LucideIcons.clock, 'Menunggu tinjauan manual', AppColors.primary),
      _ => (LucideIcons.shieldCheck, 'Foto lolos validasi', AppColors.primary),
    };
    // The answer arrives after the page opened, so a screen reader is told when it changes.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(children: [
        if (icon == null && !Motion.reduced(context))
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary))
        else
          Icon(icon ?? LucideIcons.scanEye, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: AppTypography.text(13, weight: 600))),
      ]),
    );
  }

  /// A photo the AI turned down (retake, not food) or could not check: what happened and how to go on.
  Widget _problem(ShareCapture capture) {
    final r = capture.result;
    final failed = r == null;
    final text = failed
        ? '${validationFailureText(capture.failure)} Foto belum dianggap lolos.'
        : r.message ?? msgNotFood;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InfoBox(
        text,
        title: failed ? 'Pemeriksaan AI gagal' : (r.verdict == AiVerdict.retake ? 'Foto kurang jelas' : 'Foto tidak bisa dipakai'),
        icon: failed ? LucideIcons.wifiOff : (r.verdict == AiVerdict.retake ? LucideIcons.focus : LucideIcons.x),
        iconColor: AppColors.error,
      ),
      const SizedBox(height: 10),
      if (failed) ...[
        AppButton(label: 'Coba lagi', variant: AppButtonVariant.outline, onPressed: () => ref.read(shareCaptureProvider.notifier).retry()),
        const SizedBox(height: 10),
      ],
      AppButton(label: 'Foto ulang', variant: failed ? AppButtonVariant.ghost : AppButtonVariant.outline, onPressed: () => context.canPop() ? context.pop() : context.go('/share/camera')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // The AI answer arrives while this form is open: fill the fields the provider has not touched yet.
    ref.listen(shareCaptureProvider, (_, next) {
      if (next != null && next.eligible) setState(() => _fillFromAi(next));
    });
    final capture = ref.watch(shareCaptureProvider);
    final now = ref.watch(clockProvider)();
    final result = capture?.result;
    final pending = result?.verdict == AiVerdict.pendingReview;
    final checked = capture != null && capture.eligible;
    final notes = result?.warnings ?? const <String>[];
    // The reason is only worth repeating when it says more than "Foto lolos validasi".
    final reason = pending ? result?.message : null;

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
                              _aiStatus(capture),
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
                  if (capture != null && !capture.checking && !checked) ...[
                    const SizedBox(height: 12),
                    _problem(capture),
                  ],
                  if (checked && (notes.isNotEmpty || reason != null)) ...[
                    const SizedBox(height: 12),
                    InfoBox(
                      [?reason, if (notes.isNotEmpty) 'Terlihat di foto: ${notes.join('; ')}.', 'Pengecekan foto oleh AI bukan jaminan keamanan pangan.'].join('\n'),
                      title: 'Catatan AI',
                      icon: LucideIcons.scanEye,
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppTextField(label: 'Nama makanan', controller: _name, errorText: _nameError, hint: 'Contoh: Ayam goreng', textCapitalization: TextCapitalization.sentences, onChanged: (_) => setState(() {
                    _nameEdited = true;
                    _nameError = null;
                  })),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Deskripsi',
                    controller: _description,
                    hint: 'Contoh: Ayam goreng bumbu kuning, 4 potong',
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    inputFormatters: [LengthLimitingTextInputFormatter(descriptionMaxLength)],
                    helperText: 'Maksimal $descriptionMaxLength karakter',
                    onChanged: (_) => _descriptionEdited = true,
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Text('Sisa berapa porsi?', style: AppTypography.display(17, weight: 700))),
                    QtyStepper(value: _portions, max: 50, onChanged: (v) => setState(() => _portions = v)),
                  ]),
                  if (_category != FoodCategory.sealedFood) ...[
                    const SizedBox(height: 16),
                    Text('Kemasan', style: AppTypography.display(17, weight: 700)),
                    const SizedBox(height: 8),
                    SegmentedControl(
                      options: [for (final p in Packaging.values) p.label],
                      selected: _packaging.index,
                      onChanged: (i) => setState(() {
                        _packaging = Packaging.values[i];
                        if (_packaging == Packaging.wadahSendiri) _delivery = false; // food in the receiver's own container is not delivered
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _packaging == Packaging.wadahSendiri ? 'Penerima diminta membawa wadah bersih sendiri. Hemat kemasan sekali pakai.' : 'Sudah dibungkus, penerima tinggal membawa pulang.',
                      style: AppTypography.text(13, color: AppColors.inkMuted),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Pilihan sehat', style: AppTypography.display(17, weight: 700)),
                  const SizedBox(height: 4),
                  Text('Ditandai otomatis oleh AI. Ubah kalau kurang tepat.', style: AppTypography.text(13, color: AppColors.inkMuted)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in HealthTag.values)
                      AppChip(label: t.label, selected: _healthTags.contains(t), onTap: () => setState(() {
                          _tagsEdited = true;
                          _healthTags.contains(t) ? _healthTags.remove(t) : _healthTags.add(t);
                        })),
                  ]),
                  if (_category == FoodCategory.bahanMentah) _recipeSection(),
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
                  Text('Cara serah terima', style: AppTypography.display(17, weight: 700)),
                  AppCheckbox(
                    value: _pickup,
                    label: 'Ambil di tempat',
                    textSize: 15,
                    helper: 'Penerima datang ke titik ambil',
                    onChanged: (v) => setState(() => _pickup = v),
                  ),
                  AppCheckbox(
                    value: _delivery,
                    label: 'Bisa diantar (< 1 km)',
                    textSize: 15,
                    enabled: _packagingNow == Packaging.dibungkus,
                    helper: _packagingNow == Packaging.dibungkus ? 'Kamu antar sendiri ke penerima' : 'Antar hanya untuk makanan yang sudah dibungkus.',
                    onChanged: (v) => setState(() => _delivery = v),
                  ),
                  // Shown as soon as both are off; "Bagikan sekarang" refuses it too.
                  if (Validators.handover(_pickup, _delivery ? _deliveryFee : null) case final error?) ...[
                    const SizedBox(height: 4),
                    Text(error, style: AppTypography.text(13, weight: 600, color: AppColors.error)),
                    const SizedBox(height: 12),
                  ],
                  if (_delivery) ...[
                    const SizedBox(height: 4),
                    Text('Ongkir', style: AppTypography.text(14, weight: 600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final fee in deliveryFeeOptions)
                        AppChip(label: formatRupiah(fee), selected: _deliveryFee == fee, onTap: () => setState(() => _deliveryFee = fee)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Ongkir seluruhnya untukmu.', style: AppTypography.text(13, color: AppColors.inkMuted)),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 5),
                  Text(_pickup ? 'Ambil paling lambat jam' : 'Antar paling lambat jam', style: AppTypography.display(17, weight: 700)),
                  const SizedBox(height: 8),
                  TimeChips(times: _times, selected: _pickupBy, now: now, custom: _customPickup, onSelected: (t) => setState(() => _pickupBy = t), onCustom: _pickCustomTime),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Icon(LucideIcons.mapPin, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FadeSwitch(
                        child: Text('${_pickup ? 'Titik ambil' : 'Antar dari'}: ${_point.name}', key: ValueKey(_point.id), style: AppTypography.text(13, weight: 500, color: AppColors.inkMuted)),
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
                // Off while the AI is still looking or turned the photo down: the reason is already on screen above.
                AppButton(label: 'Bagikan sekarang', onPressed: capture == null || capture.eligible ? _publish : null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
