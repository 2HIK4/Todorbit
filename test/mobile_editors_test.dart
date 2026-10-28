import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/calendar/session_editor.dart';
import 'package:life_manager/features/mobile/mobile_calendar.dart';

void main() {
  testWidgets(
    'recurring mobile event fits a small phone and guards unsaved Back',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      final c = AppController(LifeRepository(db));
      await c.refresh();
      final day = DateTime.now();
      final event = FixedEvent(
        id: 'occurrence',
        title: 'Recurring meeting',
        notes: '',
        startsAt: day,
        endsAt: day.add(const Duration(hours: 1)),
        createdAt: day,
        updatedAt: day,
        nominalDate: localDate(day),
        repeat: const EventRepeat(kind: EventRepeatKind.weekly),
      );
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appControllerProvider.overrideWith((ref) => c)],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => openMobileEditor(
                      context,
                      (route) => EventEditor(
                        protectUnsavedEdits: true,
                        event: event,
                        initialDay: day,
                        onClose: () => Navigator.pop(route),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.widgetWithText(TextField, 'Title *'),
          'Revised meeting',
        );
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(find.byType(EventEditor), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      }
    },
  );
  testWidgets('mobile session editor fits at large text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    final c = AppController(LifeRepository(db));
    await c.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => c)],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: SessionEditor(
                  protectUnsavedEdits: true,
                  initialDay: DateTime.now(),
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    }
  });
}
