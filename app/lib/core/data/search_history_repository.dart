import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_repository.dart';

/// "Pencarian terakhir" on the Beranda search page: what the user searched for, newest first. Kept on the device
/// (memory only in tests, where there are no preferences).
class SearchHistoryNotifier extends Notifier<List<String>> {
  static const _key = 'search_history';
  static const max = 8;

  @override
  List<String> build() => ref.read(preferencesProvider)?.getStringList(_key) ?? const [];

  /// Puts [term] on top; the same words in any letter case replace their older entry.
  void add(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    _set([t, for (final s in state) if (s.toLowerCase() != t.toLowerCase()) s].take(max).toList());
  }

  void remove(String term) => _set([for (final s in state) if (s != term) s]);

  void clear() => _set(const []);

  void _set(List<String> terms) {
    state = terms;
    unawaited(ref.read(preferencesProvider)?.setStringList(_key, terms));
  }
}

final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);
