import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/shared/status_snackbar.dart';

void main() {
  group('Notification Auto-Dismiss Tests (UX-01)', () {
    testWidgets(
      'shared status replaces repeats and allows extra reading time',
      (tester) async {
        var count = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(accessibleNavigation: true),
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showTransientStatus(
                      context,
                      'Error ${++count}',
                      type: NotificationType.error,
                    ),
                    child: const Text('Show latest'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show latest'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).duration,
          const Duration(seconds: 14),
        );
        await tester.tap(find.text('Show latest'));
        await tester.pumpAndSettle();
        expect(find.text('Error 1'), findsNothing);
        expect(find.text('Error 2'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 35));
        expect(tester.takeException(), isNull);
      },
    );
    test('notificationDuration matches expected defaults', () {
      expect(
        notificationDuration(NotificationType.success),
        const Duration(seconds: 3),
      );
      expect(
        notificationDuration(NotificationType.info),
        const Duration(seconds: 4),
      );
      expect(
        notificationDuration(NotificationType.warning),
        const Duration(seconds: 5),
      );
      expect(
        notificationDuration(NotificationType.error),
        const Duration(seconds: 7),
      );
    });

    testWidgets(
      'transientStatusSnackBar configures persist: false and auto-dismisses',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      transientStatusSnackBar(
                        context,
                        'Item saved successfully',
                        type: NotificationType.success,
                      ),
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle(); // Settle entrance animation

        // SnackBar is present and persist is false
        final snackFinder = find.byType(SnackBar);
        expect(snackFinder, findsOneWidget);
        final snack = tester.widget<SnackBar>(snackFinder);
        expect(snack.persist, isFalse);
        expect(snack.duration, const Duration(seconds: 3));

        // Advance by 3 seconds (success duration)
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // SnackBar must have automatically dismissed without user intervention
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'transientStatusSnackBar error type configures 7s duration, persist: false, and auto-dismisses',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      transientStatusSnackBar(
                        context,
                        'Could not perform action',
                        type: NotificationType.error,
                      ),
                    );
                  },
                  child: const Text('Show Error'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Error'));
        await tester.pumpAndSettle();

        final snackFinder = find.byType(SnackBar);
        expect(snackFinder, findsOneWidget);
        final snack = tester.widget<SnackBar>(snackFinder);
        expect(snack.persist, isFalse);
        expect(snack.duration, const Duration(seconds: 7));

        // At 4 seconds, error notification is still readable and visible
        await tester.pump(const Duration(seconds: 4));
        expect(find.byType(SnackBar), findsOneWidget);

        // Advance remaining 3 seconds to complete 7s duration
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Automatically dismissed
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });
}
