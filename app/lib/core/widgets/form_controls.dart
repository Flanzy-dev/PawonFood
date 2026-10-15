import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/motion.dart';
import '../motion/pressable.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'brand_icons.dart';

/// Groups digits with dots while typing (5000 -> 5.000), like the price format in the design.
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Parses "5.000" back to 5000.
int? parseAmount(String text) => int.tryParse(text.replaceAll('.', ''));

/// Two-option segmented control (Gratis / Jual murah, Saya menerima / Saya berbagi). Sand track, selected white.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({super.key, required this.options, required this.selected, required this.onChanged, this.badges});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  /// Optional unread counts, same length as [options].
  final List<int>? badges;

  @override
  Widget build(BuildContext context) => Container(
        // minHeight, not a fixed height: at large text sizes the labels need more room than 56.
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.surfaceSand, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Stack(alignment: Alignment.center, children: [
          // The white thumb slides to the selected option instead of jumping.
          Positioned.fill(
            child: AnimatedAlign(
              duration: Motion.of(context, Motion.base),
              curve: Motion.move,
              alignment: Alignment(options.length < 2 ? 0 : -1 + 2 * selected / (options.length - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / options.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < options.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: options[i],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Container(
                        // Each option is as tall as the track's inside (56 - 2 x 6 padding - 2 x 1 border), so the label sits in the
                        // middle of the white thumb and the whole option is the tap target. Taller only when large text needs it.
                        constraints: const BoxConstraints(minHeight: 42),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: AnimatedDefaultTextStyle(
                                duration: Motion.of(context, Motion.base),
                                style: AppTypography.text(16, weight: i == selected ? 700 : 600, color: i == selected ? AppColors.ink : AppColors.inkMuted),
                                child: Text(options[i], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            if (badges != null && badges![i] > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                child: Text('${badges![i]}', style: AppTypography.text(13, weight: 700, color: AppColors.background)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]),
      );
}

/// "−" sand circle, value, "+" green circle.
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 99});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) => Container(
        width: 140,
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RoundButton(icon: LucideIcons.minus, fill: AppColors.surfaceSand, color: AppColors.ink, label: 'Kurangi porsi', onTap: value > min ? () => onChanged(value - 1) : null),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(a), child: child)),
              child: Text('$value', key: ValueKey(value), style: AppTypography.text(20, weight: 700)),
            ),
            _RoundButton(icon: LucideIcons.plus, fill: AppColors.primary, color: AppColors.background, label: 'Tambah porsi', onTap: value < max ? () => onChanged(value + 1) : null),
          ],
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.fill, required this.color, required this.label, required this.onTap});

  final IconData icon;
  final Color fill;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: Pressable(
          enabled: onTap != null,
          scale: 0.9,
          child: Material(
            color: onTap == null ? fill.withValues(alpha: 0.5) : fill,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: onTap == null ? color.withValues(alpha: 0.4) : color))),
          ),
        ),
      );
}

/// Equal-width pickup deadline chips (19.00 / 20.30 / 22.00). Times that already passed are disabled. With [onCustom]
/// a fourth chip "Atur jam" lets the provider pick any time; once [custom] is set the chip shows that time and is
/// selected while it is the chosen deadline. Tapping it always reopens the picker.
class TimeChips extends StatelessWidget {
  const TimeChips({super.key, required this.times, required this.selected, required this.now, required this.onSelected, this.onCustom, this.custom});

  final List<DateTime> times;
  final DateTime? selected;
  final DateTime now;
  final ValueChanged<DateTime> onSelected;

  /// Opens the time picker; null hides the "Atur jam" chip.
  final VoidCallback? onCustom;

  /// The deadline the provider picked with "Atur jam", shown on the fourth chip.
  final DateTime? custom;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < times.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _chip(context, times[i])),
          ],
          if (onCustom != null) ...[const SizedBox(width: 8), Expanded(child: _customChip(context))],
        ],
      );

  Widget _chipShell(BuildContext context, {required bool on, required bool enabled, required Color border, required VoidCallback? onTap, required Widget child}) => Pressable(
        enabled: enabled,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.move,
          decoration: ShapeDecoration(
            color: on ? AppColors.primary : AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: on ? AppColors.primary : border, width: border == AppColors.primary && !on ? 1.5 : 1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap, child: Container(height: 52, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 6), child: FittedBox(fit: BoxFit.scaleDown, child: child))),
          ),
        ),
      );

  Widget _chip(BuildContext context, DateTime t) {
    final enabled = t.isAfter(now);
    final on = selected != null && selected!.isAtSameMomentAs(t);
    return Semantics(
      button: true,
      selected: on,
      enabled: enabled,
      label: 'Ambil paling lambat ${formatTime(t)}',
      child: _chipShell(
        context,
        on: on,
        enabled: enabled,
        border: AppColors.border,
        onTap: enabled ? () => onSelected(t) : null,
        child: Text(formatTime(t), style: AppTypography.text(16, weight: 700, color: on ? AppColors.background : (enabled ? AppColors.ink : AppColors.inkMuted.withValues(alpha: 0.5)))),
      ),
    );
  }

  Widget _customChip(BuildContext context) {
    final t = custom;
    final on = t != null && selected != null && selected!.isAtSameMomentAs(t);
    return Semantics(
      button: true,
      selected: on,
      label: t == null ? 'Atur jam ambil sendiri' : 'Ambil paling lambat ${formatTime(t)}, ketuk untuk mengubah',
      child: _chipShell(
        context,
        on: on,
        enabled: true,
        border: t == null ? AppColors.primary : AppColors.border,
        onTap: onCustom,
        child: t == null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.pencil, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Atur jam', style: AppTypography.text(14, weight: 700, color: AppColors.primary)),
              ])
            : Text(formatTime(t), style: AppTypography.text(16, weight: 700, color: on ? AppColors.background : AppColors.ink)),
      ),
    );
  }
}

/// Green checkbox with a label and an optional muted explanation line under it.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged, required this.label, this.textSize = 14, this.helper});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final double textSize;
  final String? helper;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: value,
        label: helper == null ? label : '$label. $helper',
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: value ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: value ? null : Border.all(color: AppColors.borderStrong, width: 1.5),
                    ),
                    child: AnimatedScale(
                      scale: value ? 1 : 0.5,
                      duration: Motion.of(context, Motion.base),
                      curve: value ? Motion.pop : Motion.exit,
                      child: AnimatedOpacity(
                        opacity: value ? 1 : 0,
                        duration: Motion.of(context, Motion.base),
                        child: const Icon(LucideIcons.check, size: 16, color: AppColors.background),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTypography.text(textSize, weight: 500, height: textSize * 1.4)),
                        if (helper != null) Text(helper!, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Text field with a label above, error text with an icon below (never color-only), and an optional eye toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.helperText,
    this.password = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffixText,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.semanticLabel,
  });

  final String label;

  /// Name read by screen readers when the visible [label] is empty or not enough (e.g. the price field).
  final String? semanticLabel;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final bool password;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? prefix;
  final String? suffixText;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.password;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(widget.label, style: AppTypography.display(16, weight: 700, height: 22)),
          const SizedBox(height: 6),
        ],
        Semantics(
          // The visible label is a separate Text, so the field would have no accessible name without this.
          label: widget.semanticLabel ?? (widget.label.isNotEmpty ? widget.label : widget.hint),
          child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: AppTypography.text(16, weight: 500),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTypography.text(16, color: AppColors.inkMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            prefixIcon: widget.prefix == null ? null : Padding(padding: const EdgeInsets.only(left: 16, right: 8), child: Text(widget.prefix!, style: AppTypography.text(16, weight: 700, color: AppColors.inkMuted))),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixText: widget.suffixText,
            suffixStyle: AppTypography.text(14, color: AppColors.inkMuted),
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: _obscured ? 'Tampilkan password' : 'Sembunyikan password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: _obscured ? const FluentEyeOffIcon() : const FluentEyeIcon(),
                  )
                : null,
            enabledBorder: border(hasError ? AppColors.error : AppColors.borderStrong, hasError ? 1.5 : 1),
            focusedBorder: border(hasError ? AppColors.error : AppColors.primary, 1.5),
          ),
        ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.error)),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.errorText!, style: AppTypography.text(13, weight: 600, height: 18, color: AppColors.error))),
            ]),
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(widget.helperText!, style: AppTypography.text(13, height: 18, color: AppColors.inkMuted)),
        ],
      ],
    );
  }
}
