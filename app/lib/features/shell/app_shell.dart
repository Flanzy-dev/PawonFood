import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/navigation_widgets.dart';

/// Hosts the four tabs and the bottom navigation with the raised Bagikan FAB.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => PopScope(
        // System Back on Peta, Pesan or Profil goes to Beranda first; only Beranda lets the app close.
        canPop: navigationShell.currentIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) navigationShell.goBranch(0);
        },
        child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: navigationShell),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PawonBottomNav(
                currentIndex: navigationShell.currentIndex,
                onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
                onShare: () => context.push('/share/camera'),
              ),
            ),
          ],
        ),
        ),
      );
}
