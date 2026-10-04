import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/data/session_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/messages_screen.dart';
import 'features/home/all_food_screen.dart';
import 'features/home/home_screen.dart';
import 'features/listing/listing_detail_screen.dart';
import 'features/map/map_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/reward_detail_screen.dart';
import 'features/profile/rewards_screen.dart';
import 'features/profile/voucher_claimed_screen.dart';
import 'features/review/review_screen.dart';
import 'features/share/camera_screen.dart';
import 'features/share/share_done_screen.dart';
import 'features/share/share_form_screen.dart';
import 'features/shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

const _authRoutes = {'/welcome', '/register', '/login'};

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier<bool>(ref.read(sessionProvider) != null);
  ref.listen(sessionProvider, (_, next) => signedIn.value = next != null);
  ref.onDispose(signedIn.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: signedIn,
    redirect: (context, state) {
      final isAuthRoute = _authRoutes.contains(state.matchedLocation);
      if (!signedIn.value && !isAuthRoute) return '/welcome';
      if (signedIn.value && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/map', builder: (_, _) => const MapScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/messages', builder: (_, _) => const MessagesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/semua', builder: (_, _) => const AllFoodScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/rewards', builder: (_, _) => const RewardsScreen()),
      // '/reward/claimed' must stay before '/reward/:id'
      GoRoute(parentNavigatorKey: _rootKey, path: '/reward/claimed', builder: (_, _) => const VoucherClaimedScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/reward/:id', builder: (_, s) => RewardDetailScreen(rewardId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/listing/:id', builder: (_, s) => ListingDetailScreen(listingId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/chat/:id', builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/review/:id', builder: (_, s) => ReviewScreen(conversationId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/share/camera', builder: (_, _) => const CameraScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/share/form', builder: (_, _) => const ShareFormScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/share/done/:id', builder: (_, s) => ShareDoneScreen(listingId: s.pathParameters['id']!)),
    ],
  );
});
