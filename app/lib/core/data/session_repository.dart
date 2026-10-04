import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_data.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import 'providers.dart';

/// Signed-in user (null = signed out). The MVP has no real auth: any input with a valid format is accepted.
class SessionNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  /// Demo login: signs in as the seeded persona.
  void login(String emailOrPhone) {
    final base = ref.read(mockDataProvider).user;
    state = emailOrPhone.contains('@') ? base.copyWith(email: emailOrPhone.trim()) : base;
  }

  /// New account: starts with 0 points. Seeded chats stay available so the whole journey can be demoed.
  void register({required String name, required String emailOrPhone, required Set<UserRole> roles}) {
    final base = ref.read(mockDataProvider).user;
    state = AppUser(id: meId, name: name.trim(), email: emailOrPhone.trim(), roles: roles, pickupPoint: base.pickupPoint);
  }

  void logout() => state = null;

  void addPoints(int delta) {
    final u = state;
    if (u != null && delta != 0) state = u.copyWith(points: u.points + delta);
  }

  void addShared(int portions) {
    final u = state;
    if (u != null) state = u.copyWith(portionsShared: u.portionsShared + portions);
  }

  void addSaved(int portions) {
    final u = state;
    if (u != null) state = u.copyWith(portionsSaved: u.portionsSaved + portions);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, AppUser?>(SessionNotifier.new);
