import 'package:flutter/cupertino.dart' show CupertinoPicker, FixedExtentScrollController;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/formatters.dart';
import '../services/pickup_times.dart';
import '../services/validators.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_sheet.dart';

/// C15g "Atur jam ambil": the provider picks the latest pickup time with an hour and a minute wheel (5-minute steps).
/// Resolves the chosen time, or null when the sheet is dismissed. Times outside 30 minutes to 6 hours from [now] show a
/// red explanation and keep "Pakai jam ini" disabled (C15h).
Future<DateTime?> showPickupTimeSheet(BuildContext context, {required DateTime now, DateTime? initial}) =>
    showAppSheet<DateTime>(context: context, builder: (_) => _PickupTimeSheet(now: now, initial: initial));

class _PickupTimeSheet extends StatefulWidget {
  const _PickupTimeSheet({required this.now, this.initial});

  final DateTime now;
  final DateTime? initial;

  @override
  State<_PickupTimeSheet> createState() => _PickupTimeSheetState();
}

class _PickupTimeSheetState extends State<_PickupTimeSheet> {
  static const _rowHeight = 40.0;

  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hours;
  late final FixedExtentScrollController _minutes;

  @override
  void initState() {
    super.initState();
    final earliest = pickupEarliest(widget.now), latest = pickupLatest(widget.now);
    var start = widget.initial ?? earliest.add(const Duration(minutes: 60));
    if (start.isBefore(earliest) || start.isAfter(latest)) start = earliest.add(const Duration(minutes: 60)).isAfter(latest) ? earliest : earliest.add(const Duration(minutes: 60));
    _hour = start.hour;
    _minute = start.minute - start.minute % pickupStepMinutes;
    _hours = FixedExtentScrollController(initialItem: _hour);
    _minutes = FixedExtentScrollController(initialItem: _minute ~/ pickupStepMinutes);
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  DateTime get _picked => nextOccurrence(widget.now, _hour, _minute);

  /// "3 jam lagi", "1 jam 20 mnt lagi", "45 menit lagi".
  String _lead(DateTime t) {
    final m = t.difference(DateTime(widget.now.year, widget.now.month, widget.now.day, widget.now.hour, widget.now.minute)).inMinutes;
    if (m < 60) return '$m menit lagi';
    return m % 60 == 0 ? '${m ~/ 60} jam lagi' : '${m ~/ 60} jam ${m % 60} mnt lagi';
  }

  Widget _wheel({required String label, required FixedExtentScrollController controller, required int count, required int selected, required int step, required bool bad, required ValueChanged<int> onChanged}) {
    return Semantics(
      label: label,
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: _rowHeight,
        looping: true,
        diameterRatio: 1.8,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          onChanged(i % count * step);
        },
        children: [
          for (var i = 0; i < count; i++)
            Center(
              child: Builder(builder: (_) {
                final d = [(i - selected ~/ step) % count, (selected ~/ step - i) % count].reduce((a, b) => a < b ? a : b);
                final style = d == 0
                    ? AppTypography.display(28, weight: 800, color: bad ? AppColors.error : AppColors.ink)
                    : AppTypography.display(d == 1 ? 22 : 20, weight: d == 1 ? 600 : 500, color: d == 1 ? AppColors.inkMuted : AppColors.inkMuted.withValues(alpha: 0.55));
                return Text((i * step).toString().padLeft(2, '0'), style: style);
              }),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final error = Validators.pickupWindow(picked, widget.now);
    final bad = error != null;
    return SheetBody(
      title: 'Jam ambil paling lambat',
      subtitle: 'Antara ${formatTime(pickupEarliest(widget.now))} dan ${formatTime(pickupLatest(widget.now))} (30 menit sampai 6 jam dari sekarang)',
      footer: AppButton(label: 'Pakai jam ini', onPressed: bad ? null : () => closeSheet(context, picked)),
      children: [
        SizedBox(
          height: _rowHeight * 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(height: _rowHeight, decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(14))),
              Center(
                child: SizedBox(
                  width: 240,
                  child: Row(
                    children: [
                      Expanded(child: _wheel(label: 'Jam', controller: _hours, count: 24, selected: _hour, step: 1, bad: bad, onChanged: (v) => setState(() => _hour = v))),
                      Text(':', style: AppTypography.display(28, weight: 800, color: bad ? AppColors.error : AppColors.ink)),
                      Expanded(child: _wheel(label: 'Menit', controller: _minutes, count: 60 ~/ pickupStepMinutes, selected: _minute, step: pickupStepMinutes, bad: bad, onChanged: (v) => setState(() => _minute = v))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: bad
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.triangleAlert, size: 18, color: AppColors.error),
                  const SizedBox(width: 6),
                  Flexible(child: Text(error, style: AppTypography.text(14, weight: 600, color: AppColors.error))),
                ])
              : Text('Ambil paling lambat ${formatTime(picked)} · ${_lead(picked)}', style: AppTypography.text(14, weight: 600)),
        ),
      ],
    );
  }
}
