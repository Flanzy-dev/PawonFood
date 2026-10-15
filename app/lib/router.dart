import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/data/onboarding_repository.dart';
import 'core/data/session_repository.dart';
import 'core/motion/transitions.dart';
import 'features/ads/ad_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/password_reset_screens.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/messages_screen.dart';
import 'features/home/all_food_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/search_screen.dart';
import 'features/listing/listing_detail_screen.dart';
import 'features/map/map_screen.dart';
import 'features/payment/payment_result_screen.dart';
import 'features/payment/payment_screen.dart';
import 'features/payment/qris_screen.dart';
import 'features/pickup/expired_screen.dart';
import 'features/pickup/provider_qr_screen.dart';
import 'features/pickup/route_screen.dart';
import 'features/pickup/scan_screen.dart';
import 'features/profile/profile_extras.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/reward_detail_screen.dart';
import 'features/profile/rewards_screen.dart';
import 'features/profile/voucher_claimed_screen.dart';
import 'features/review/review_screen.dart';
import 'features/settings/change_password_screen.dart';
import 'features/settings/help_screens.dart';
import 'features/settings/notifications_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/share/camera_screen.dart';
import 'features/share/map_picker_screen.dart';
import 'features/share/share_done_screen.dart';
import 'features/share/share_form_screen.dart';
import 'features/shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

const _authRoutes = {'/welcome', '/register', '/login'};

/// Reachable signed in or out (password reset from Masuk, or "Lupa password lama?" in Pengaturan).
const _openRoutes = {'/forgot', '/forgot/code', '/forgot/new'};

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier<bool>(ref.read(sessionProvider) != null);
  ref.listen(sessionProvider, (_, next) => signedIn.value = next != null);
  ref.onDispose(signedIn.dispose);
  final onboarded = ValueNotifier<bool>(ref.read(onboardingSeenProvider));
  ref.listen(onboardingSeenProvider, (_, next) => onboarded.value = next);
  ref.onDispose(onboarded.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: Listenable.merge([signedIn, onboarded]),
    redirect: (context, state) {
      // First launch on this device: the intro comes before everything else.
      if (!onboarded.value) return state.matchedLocation == '/onboarding' ? null : '/onboarding';
      if (state.matchedLocation == '/onboarding') return signedIn.value ? '/' : '/welcome';
      if (_openRoutes.contains(state.matchedLocation)) return null;
      final isAuthRoute = _authRoutes.contains(state.matchedLocation);
      if (!signedIn.value && !isAuthRoute) return '/welcome';
      if (signedIn.value && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', pageBuilder: (_, s) => motionPage(s, const OnboardingScreen(), motion: PageMotion.fade)),
      GoRoute(path: '/welcome', pageBuilder:(_, s) => motionPage(s, const WelcomeScreen(), motion: PageMotion.fade)),
      GoRoute(path: '/register', pageBuilder: (_, s) => motionPage(s, const RegisterScreen(), motion: PageMotion.fade)),
      GoRoute(path: '/login', pageBuilder: (_, s) => motionPage(s, const LoginScreen(), motion: PageMotion.fade)),
      GoRoute(path: '/forgot', pageBuilder: (_, s) => motionPage(s, const ForgotPasswordScreen())),
      GoRoute(path: '/forgot/code', pageBuilder: (_, s) => motionPage(s, VerifyCodeScreen(contact: (s.extra as String?) ?? ''))),
      GoRoute(path: '/forgot/new', pageBuilder: (_, s) => motionPage(s, const NewPasswordScreen())),
      StatefulShellRoute(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        navigatorContainerBuilder: (_, shell, children) => FadeIndexedStack(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/map', builder: (_, _) => const MapScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/messages', builder: (_, _) => const MessagesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/semua', pageBuilder: (_, s) => motionPage(s, const AllFoodScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/search', pageBuilder: (_, s) => motionPage(s, const SearchScreen(), motion: PageMotion.fade)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/rewards', pageBuilder: (_, s) => motionPage(s, const RewardsScreen())),
      // '/reward/claimed' must stay before '/reward/:id'
      GoRoute(parentNavigatorKey: _rootKey, path: '/reward/claimed', pageBuilder: (_, s) => motionPage(s, const VoucherClaimedScreen(), motion: PageMotion.fade)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/reward/:id', pageBuilder: (_, s) => motionPage(s, RewardDetailScreen(rewardId: s.pathParameters['id']!))),
      GoRoute(parentNavigatorKey: _rootKey, path: '/listing/:id', pageBuilder: (_, s) => motionPage(s, ListingDetailScreen(listingId: s.pathParameters['id']!))),
      GoRoute(parentNavigatorKey: _rootKey, path: '/chat/:id', pageBuilder: (_, s) => motionPage(s, ChatScreen(conversationId: s.pathParameters['id']!))),
      GoRoute(parentNavigatorKey: _rootKey, path: '/review/:id', pageBuilder: (_, s) => motionPage(s, ReviewScreen(conversationId: s.pathParameters['id']!))),
      // Profil extras and settings
      GoRoute(parentNavigatorKey: _rootKey, path: '/profile/history', pageBuilder: (_, s) => motionPage(s, const HistoryScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/profile/points', pageBuilder: (_, s) => motionPage(s, const PickupPointsScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/certificate', pageBuilder: (_, s) => motionPage(s, const CertificateScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/vouchers', pageBuilder: (_, s) => motionPage(s, const MyVouchersScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings', pageBuilder: (_, s) => motionPage(s, const SettingsScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings/notifications', pageBuilder: (_, s) => motionPage(s, const NotificationsScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings/password', pageBuilder: (_, s) => motionPage(s, const ChangePasswordScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings/help', pageBuilder: (_, s) => motionPage(s, const HelpScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings/terms', pageBuilder: (_, s) => motionPage(s, const DocScreen.terms())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings/privacy', pageBuilder: (_, s) => motionPage(s, const DocScreen.privacy())),
      // Reserve, pay and pick up (all keyed by the conversation id)
      GoRoute(parentNavigatorKey: _rootKey, path: '/pay/:id', pageBuilder: (_, s) => motionPage(s, PaymentScreen(conversationId: s.pathParameters['id']!), motion: PageMotion.rise)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/pay/:id/qris', pageBuilder: (_, s) => motionPage(s, QrisScreen(conversationId: s.pathParameters['id']!))),
      GoRoute(parentNavigatorKey: _rootKey, path: '/pay/:id/done', pageBuilder: (_, s) => motionPage(s, PaymentResultScreen(conversationId: s.pathParameters['id']!, success: true), motion: PageMotion.fade)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/pay/:id/failed', pageBuilder: (_, s) => motionPage(s, PaymentResultScreen(conversationId: s.pathParameters['id']!, success: false), motion: PageMotion.fade)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/route/:id', pageBuilder: (_, s) => motionPage(s, RouteScreen(conversationId: s.pathParameters['id']!))),
      GoRoute(parentNavigatorKey: _rootKey, path: '/scan/:id', pageBuilder: (_, s) => motionPage(s, ScanScreen(conversationId: s.pathParameters['id']!), motion: PageMotion.rise)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/expired/:id', pageBuilder: (_, s) => motionPage(s, ExpiredScreen(conversationId: s.pathParameters['id']!), motion: PageMotion.fade)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/qr/:id', pageBuilder: (_, s) => motionPage(s, ProviderQrScreen(conversationId: s.pathParameters['id']!), motion: PageMotion.rise)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/qr/:id/done', pageBuilder: (_, s) => motionPage(s, ProviderPickupDoneScreen(conversationId: s.pathParameters['id']!), motion: PageMotion.fade)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/ad', pageBuilder: (_, s) => motionPage(s, const AdScreen(), motion: PageMotion.fade)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/share/camera', pageBuilder: (_, s) => motionPage(s, const CameraScreen(), motion: PageMotion.rise)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/share/form', pageBuilder: (_, s) => motionPage(s, const ShareFormScreen())),
      GoRoute(parentNavigatorKey: _rootKey, path: '/share/pick-point', pageBuilder: (_, s) => motionPage(s, const MapPickerScreen(), motion: PageMotion.rise)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/share/done/:id', pageBuilder: (_, s) => motionPage(s, ShareDoneScreen(listingId: s.pathParameters['id']!), motion: PageMotion.fade)),
    ],
  );
});
