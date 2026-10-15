import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data/listings_repository.dart';
import '../../core/data/search_history_repository.dart';
import '../../core/motion/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/layout_widgets.dart';
import '../../core/widgets/navigation_widgets.dart';
import '../../core/widgets/term_row.dart';

/// Hero tag shared by the Beranda search bar and the bar on this page.
const searchHeroTag = 'beranda-search';

/// Beranda search page: the bar moves to the top of a white page that lists recent searches and popular words, then
/// suggestions while typing. Picking a term closes the page and filters the Beranda feed ([searchQueryProvider]).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _text = TextEditingController(text: ref.read(searchQueryProvider));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Filters the feed with [term] and goes back to Beranda. An empty term clears the filter.
  void _apply(String term) {
    final t = term.trim();
    ref.read(searchQueryProvider.notifier).state = t;
    ref.read(searchHistoryProvider.notifier).add(t);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  RoundIconButton(icon: LucideIcons.arrowLeft, semanticLabel: 'Kembali', onTap: () => context.pop()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SearchField(
                      hint: 'Cari lauk, nasi, roti...',
                      controller: _text,
                      autofocus: true,
                      heroTag: searchHeroTag,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _apply,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: EntranceScope(
                child: ListenableBuilder(
                  listenable: _text,
                  builder: (context, _) => _text.text.trim().isEmpty ? _Suggestions(onPick: _apply) : _Matches(text: _text.text.trim(), onPick: _apply),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty bar: "Pencarian terakhir" and "Populer di sekitarmu".
class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final popular = ref.watch(popularKeywordsProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 16),
      children: [
        if (history.isNotEmpty)
          FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle('Pencarian terakhir', actionLabel: 'Hapus semua', onAction: () => ref.read(searchHistoryProvider.notifier).clear()),
                for (final term in history)
                  TermRow(
                    icon: LucideIcons.history,
                    label: term,
                    onTap: () => onPick(term),
                    onRemove: () => ref.read(searchHistoryProvider.notifier).remove(term),
                  ),
              ],
            ),
          ),
        if (popular.isNotEmpty)
          FadeSlideIn(
            index: 1,
            child: Padding(
              padding: EdgeInsets.only(top: history.isEmpty ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Populer di sekitarmu'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (final w in popular) AppChip(label: w, selected: false, onTap: () => onPick(w))]),
                ],
              ),
            ),
          ),
        if (history.isEmpty && popular.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 32), child: Center(child: Text('Ketik nama makanan atau pemberi.', style: AppTypography.bodyMuted))),
      ],
    );
  }
}

/// Typed text: "Cari ..." plus the nearby foods whose name matches.
class _Matches extends ConsumerWidget {
  const _Matches({required this.text, required this.onPick});

  final String text;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = text.toLowerCase();
    final names = <String>[];
    for (final l in ref.watch(nearbyListingsProvider)) {
      if (l.name.toLowerCase().contains(q) && !names.contains(l.name)) names.add(l.name);
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 16),
      children: [
        TermRow(icon: LucideIcons.search, label: 'Cari "$text"', onTap: () => onPick(text)),
        for (final n in names.take(5)) TermRow(icon: LucideIcons.utensils, label: n, onTap: () => onPick(n)),
      ],
    );
  }
}
