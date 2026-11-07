import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/alarms.dart';
import 'package:life_manager/features/shared/alarm_field.dart';

void main() {
  testWidgets('alarm starts compact and removal clears only its draft', (
    tester,
  ) async {
    var value = const AlarmConfig();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, update) => AlarmField(
                value: value,
                onChanged: (next) => update(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Add alarm'), findsOneWidget);
    expect(find.text('Sound and options'), findsNothing);
    await tester.tap(find.text('Add alarm'));
    await tester.pumpAndSettle();
    expect(value.enabled, isTrue);
    await tester.tap(find.text('Sound and options'));
    await tester.pumpAndSettle();
    expect(find.text('Vibrate on Android'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove alarm'));
    await tester.pumpAndSettle();
    expect(value.enabled, isFalse);
    expect(find.text('Add alarm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'event alarm defaults to event-relative with no invented task time',
    (tester) async {
      var value = const AlarmConfig();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, update) => AlarmField(
                  value: value,
                  event: true,
                  onChanged: (next) => update(() => value = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add alarm'));
      await tester.pumpAndSettle();
      expect(value.mode, 'relative');
      expect(find.text('At or before event start'), findsOneWidget);
      expect(find.text('On the planned day'), findsNothing);
      expect(value.durationSeconds, 30);
    },
  );
}
