import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device key-value storage, overridden in main.dart. Null in tests: onboarding then counts as seen, so the app opens
/// on Welcome as before.
final preferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// True once the first-launch onboarding (A0a-A0c) was finished or skipped on this device.
class OnboardingNotifier extends Notifier<bool> {
  static const _key = 'onboarding_seen';

  @override
  bool build() {
    final prefs = ref.read(preferencesProvider);
    return prefs == null || (prefs.getBool(_key) ?? false);
  }

  void finish() {
    state = true;
    unawaited(ref.read(preferencesProvider)?.setBool(_key, true));
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
