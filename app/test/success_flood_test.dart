import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawonfood/core/motion/motion_widgets.dart';
import 'package:pawonfood/core/motion/success_flood.dart';

/// The green success flood. These tests run with animations on (the app tests run reduced, where it never shows).
void main() {
  final flood = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Flood');

  Widget host(Widget child, {bool reduced = false}) => MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  testWidgets('CheckBurst(flood) covers the screen, then settles into the badge and is gone', (tester) async {
    await tester.pumpWidget(host(const CheckBurst(size: 96, flood: true)));
    await tester.pump(); // the post-frame callback measures the badge and inserts the flood
    await tester.pump(const Duration(milliseconds: 400));
    expect(flood, findsOneWidget);
    // Taps are absorbed while it is up.
    expect(tester.widget<AbsorbPointer>(find.descendant(of: flood, matching: find.byType(AbsorbPointer))).absorbing, isTrue);
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // each phase starts on the next frame
    }
    expect(flood, findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('no flood when motion is reduced', (tester) async {
    await tester.pumpWidget(host(const CheckBurst(size: 96, flood: true), reduced: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(flood, findsNothing);
  });

  testWidgets('whileCovered runs once, while the screen is covered', (tester) async {
    var calls = 0;
    var coveredWhenCalled = false;
    var finished = false;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => playSuccessFlood(
              context,
              origin: const Offset(200, 300),
              whileCovered: () {
                calls++;
                coveredWhenCalled = flood.evaluate().isNotEmpty;
              },
            ).then((_) => finished = true),
            child: const Text('Go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // timers too, not only frames
    }
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(coveredWhenCalled, isTrue);
    expect(finished, isTrue);
    expect(flood, findsNothing);
  });
}
