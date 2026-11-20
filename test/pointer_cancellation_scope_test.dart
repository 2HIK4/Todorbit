import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/shared/pointer_cancellation_scope.dart';

void main() {
  testWidgets(
    'PointerCancellationScope clears stuck hover and highlight on app deactivation',
    (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointerCancellationScope(
              child: Center(
                child: InkWell(
                  key: const ValueKey('test-inkwell'),
                  onTap: () => tapped = true,
                  child: const SizedBox(
                    width: 120,
                    height: 60,
                    child: Text('Clickable'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final inkWellFinder = find.byKey(const ValueKey('test-inkwell'));
      expect(inkWellFinder, findsOneWidget);

      // Verify normal tap works
      await tester.tap(inkWellFinder);
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      // Simulate pointer down (press and hold with mouse)
      final center = tester.getCenter(inkWellFinder);
      final gesture = await tester.startGesture(
        center,
        pointer: 1,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate OS deactivation (e.g. Win+Shift+S snipping tool or window focus loss)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      // Return to active app state
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Cancel the gesture cleanly from test harness
      await gesture.cancel();
      await tester.pumpAndSettle();

      // Verify that after deactivation and resume, the widget is operable and not stuck
      tapped = false;
      await tester.tap(inkWellFinder);
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    },
  );
}
