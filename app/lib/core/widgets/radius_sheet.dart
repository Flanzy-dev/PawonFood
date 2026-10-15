import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../services/formatters.dart';
import 'app_sheet.dart';
import 'option_row.dart';

/// Radius choices shared by "Radius default" (D18g) and the map's radius picker (B12d).
const radiusChoices = [500.0, 1000.0, 2000.0];

/// Bottom sheet with the three radius options. [current] reads the selected radius and [onPick] applies the choice;
/// the sheet closes shortly after, so the new selection is seen first.
void showRadiusSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required double Function(WidgetRef ref) current,
  required void Function(WidgetRef ref, double meters) onPick,
}) =>
    showAppSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final selected = current(ref);
          return SheetBody(
            title: title,
            subtitle: subtitle,
            children: [
              for (final m in radiusChoices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OptionRow(
                    title: formatRadius(m),
                    subtitle: 'Jalan kaki ± ${walkMinutes(m)} mnt',
                    tag: m == 1000 ? 'Disarankan' : null,
                    selected: m == selected,
                    onTap: () {
                      onPick(ref, m);
                      Future<void>.delayed(const Duration(milliseconds: 180), () {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      });
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
