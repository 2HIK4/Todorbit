import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/calendar/session_editor.dart';
import 'package:life_manager/features/mobile/mobile_calendar.dart';
import 'package:life_manager/features/mobile/mobile_settings.dart';
import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/shared/event_color_picker.dart';
import 'package:life_manager/features/shared/icon_picker.dart';
import 'package:life_manager/features/shared/draft_interval.dart';
import 'package:life_manager/features/time_tracking/time_tracking_dialog.dart';

void main() {
  late AppDatabase db;
  late AppController controller;
  final day = DateTime(2026, 12, 31);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    controller = AppController(LifeRepository(db));
    await controller.refresh();
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 760),
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          theme: buildAppTheme(
            brightness,
            brightness == Brightness.light
                ? ThemePalette.light
                : ThemePalette.dark,
            android: true,
          ).copyWith(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              alwaysUse24HourFormat: true,
            ),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('mobile agenda uses persisted event icon/color ($brightness)', (
      tester,
    ) async {
      await controller.addEvent(
        EventDraft(
          title: 'Colored event',
          notes: '',
          startsAt: day.add(const Duration(hours: 9)),
          endsAt: day.add(const Duration(hours: 10)),
          colorValue: 0xFFEA146A,
          iconName: 'school',
        ),
      );
      await pump(
        tester,
        MobileCalendar(initialDay: day, openTask: (_) {}, addTask: (_) {}),
        brightness: brightness,
      );
      await tester.ensureVisible(find.text('Colored event'));
      final tile = find.widgetWithText(ListTile, 'Colored event');
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.school_outlined)),
        findsOneWidget,
      );
      final icon = tester.widget<Icon>(
        find.descendant(of: tile, matching: find.byType(Icon)).first,
      );
      expect(icon.color, const Color(0xFFEA146A));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('all-day duration uses calendar dates across year boundary', () {
    expect(
      endAfterMovingStart(
        start: DateTime(2026, 10, 24),
        end: DateTime(2026, 10, 27),
        nextStart: DateTime(2026, 12, 31),
        allDay: true,
      ),
      DateTime(2027, 1, 3),
    );
    expect(
      endAfterMovingStart(
        start: day.add(const Duration(hours: 23, minutes: 30)),
        end: day.add(const Duration(days: 1, minutes: 30)),
        nextStart: DateTime(2027, 1, 31, 23, 30),
      ),
      DateTime(2027, 2, 1, 0, 30),
    );
  });

  testWidgets(
    'custom event color dialog fits short phone at 200 percent text',
    (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => chooseEventColor(context, 0xFF5365B5),
            child: const Text('Choose color'),
          ),
        ),
        size: const Size(320, 540),
        scale: 2,
      );
      await tester.tap(find.text('Choose color'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.widgetWithText(TextField, 'HEX color'));
      await tester.enterText(
        find.widgetWithText(TextField, 'HEX color'),
        '#bad',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Enter a six-digit HEX color'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('manual actual work dialog fits with IME and large text', (
    tester,
  ) async {
    await controller.addTask(const TaskDraft(title: 'Actual work'));
    await pump(
      tester,
      TimeTrackingDialog(taskId: controller.tasks.single.id),
      size: const Size(360, 640),
      scale: 2,
    );
    await tester.scrollUntilVisible(
      find.text('Add manual time'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add manual time'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Notes (optional)'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notes (optional)'),
      'Retained notes',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shared icon picker remains usable above IME at large text', (
    tester,
  ) async {
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => chooseBuiltInIcon(context, current: null),
          child: const Text('Choose icon'),
        ),
      ),
      size: const Size(320, 540),
      scale: 2,
    );
    await tester.tap(find.text('Choose icon'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'controlled select follows external value without losing identity',
    (tester) async {
      var value = 1;
      late StateSetter update;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return AnchoredSelectField<int>(
              initialValue: value,
              items: const [
                DropdownMenuItem(value: 1, child: Text('One')),
                DropdownMenuItem(value: 2, child: Text('Two')),
              ],
              onChanged: (next) => update(() => value = next!),
            );
          },
        ),
      );
      update(() => value = 2);
      await tester.pump();
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('One'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('mobile settings menu opens below field and applies selection', (
    tester,
  ) async {
    await pump(
      tester,
      MobileSettings(
        store: MobilePreferenceStore(
          File('.buildlog/verify/stage2-ui/unused-settings.json'),
        ),
        preferences: const MobilePreferences(),
        onChanged: (_) {},
      ),
    );
    final field = find.byType(AnchoredSelectField<ThemeModePreference>);
    final bounds = tester.getRect(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    final choice = find.widgetWithText(MenuItemButton, 'dark');
    expect(tester.getRect(choice).top, greaterThanOrEqualTo(bounds.bottom));
    expect(tester.getRect(choice).right, lessThanOrEqualTo(390));
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(controller.theme, ThemeModePreference.dark);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('event picker selection persists and reaches mobile agenda', (
    tester,
  ) async {
    await pump(tester, EventEditor(initialDay: day, onClose: () {}));
    await tester.enterText(
      find.widgetWithText(TextField, 'Title *'),
      'Picker result',
    );
    final color = find.byTooltip('Choose event color');
    await tester.ensureVisible(color);
    await tester.tap(color);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Rose'));
    await tester.tap(find.text('Rose'));
    await tester.pumpAndSettle();
    final icon = find.byTooltip('Choose event icon');
    await tester.ensureVisible(icon);
    await tester.tap(icon);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search icons'),
      'school',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(IconButton),
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();
    final stored = (await controller.repository.events()).single;
    expect(stored.colorValue, 0xFFB65372);
    expect(stored.iconName, 'school');
    await pump(
      tester,
      MobileCalendar(initialDay: day, openTask: (_) {}, addTask: (_) {}),
    );
    await tester.ensureVisible(find.text('Picker result'));
    final marker = find.descendant(
      of: find.widgetWithText(ListTile, 'Picker result'),
      matching: find.byIcon(Icons.school_outlined),
    );
    expect(tester.widget<Icon>(marker).color, const Color(0xFFB65372));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<void> time(
    WidgetTester tester,
    String key,
    String hour,
    String minute,
  ) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), hour);
    await tester.enterText(fields.at(1), minute);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('event start preserves duration across midnight and saves', (
    tester,
  ) async {
    await pump(tester, EventEditor(initialDay: day, onClose: () {}));
    await tester.enterText(
      find.widgetWithText(TextField, 'Title *'),
      'Overnight',
    );
    await time(tester, 'event-start-time', '23', '30');
    final date = find.byKey(const ValueKey('event-start-date'));
    await tester.ensureVisible(date);
    await tester.tap(date);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '01/01/2027');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();
    expect(
      controller.events.single.startsAt.toLocal(),
      DateTime(2027, 1, 1, 23, 30),
    );
    expect(
      controller.events.single.endsAt.difference(
        controller.events.single.startsAt,
      ),
      const Duration(hours: 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('session start preserves generated duration and saves', (
    tester,
  ) async {
    await controller.addTask(TaskDraft(title: 'Session task'));
    await pump(
      tester,
      SessionEditor(
        initialDay: day,
        initialTaskId: controller.tasks.single.id,
        onClose: () {},
      ),
    );
    await time(tester, 'session-start-time', '11', '30');
    await tester.tap(find.text('Save session'));
    await tester.pumpAndSettle();
    expect(
      controller.sessions.single.endsAt.difference(
        controller.sessions.single.startsAt,
      ),
      const Duration(hours: 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'explicit session end stays fixed and offers repair when invalid',
    (tester) async {
      await controller.addTask(const TaskDraft(title: 'Deliberate end'));
      await pump(
        tester,
        SessionEditor(
          initialDay: day,
          initialTaskId: controller.tasks.single.id,
          onClose: () {},
        ),
      );
      await time(tester, 'session-end-time', '11', '00');
      await time(tester, 'session-start-time', '10', '30');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('session-end-time')),
          matching: find.text('11:00'),
        ),
        findsOneWidget,
      );
      await time(tester, 'session-start-time', '12', '30');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('session-end-time')),
          matching: find.text('11:00'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Move end with start'));
      await tester.tap(find.text('Move end with start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save session'));
      await tester.pumpAndSettle();
      expect(
        controller.sessions.single.endsAt.toLocal(),
        DateTime(2026, 12, 31, 13),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('all-day end picker opens on displayed inclusive day', (
    tester,
  ) async {
    await controller.addEvent(
      EventDraft(
        title: 'Three days',
        notes: '',
        startsAt: day,
        endsAt: DateTime(2027, 1, 3),
        allDay: true,
      ),
    );
    await pump(
      tester,
      EventEditor(
        event: controller.events.single,
        initialDay: day,
        onClose: () {},
      ),
    );
    final end = find.byKey(const ValueKey('event-end-date'));
    await tester.ensureVisible(end);
    await tester.pumpAndSettle();
    await tester.tap(end);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate,
      DateTime(2027, 1, 2),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();
    expect(controller.events.single.endsAt.toLocal(), DateTime(2027, 1, 3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('inherited white event tint has a visible contrasting backing', (
    tester,
  ) async {
    await controller.addCategory('White events');
    final category = controller.categories.single;
    await controller.setCategoryEventColor(category.id, 0xFFFFFFFF);
    await controller.addEvent(
      EventDraft(
        title: 'Inherited event',
        notes: '',
        startsAt: day.add(const Duration(hours: 9)),
        endsAt: day.add(const Duration(hours: 10)),
        categoryId: category.id,
      ),
    );
    await pump(
      tester,
      MobileCalendar(initialDay: day, openTask: (_) {}, addTask: (_) {}),
    );
    await tester.ensureVisible(find.text('Inherited event'));
    final icon = find.descendant(
      of: find.widgetWithText(ListTile, 'Inherited event'),
      matching: find.byIcon(Icons.event_outlined),
    );
    expect(tester.widget<Icon>(icon).color, Colors.white);
    final backing = tester.widget<DecoratedBox>(
      find.ancestor(of: icon, matching: find.byType(DecoratedBox)).first,
    );
    final background = (backing.decoration as BoxDecoration).color!;
    expect(
      1.05 / (background.computeLuminance() + .05),
      greaterThanOrEqualTo(3),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('repeated event validation retains scroll, focus and draft', (
    tester,
  ) async {
    await pump(
      tester,
      EventEditor(initialDay: day, onClose: () {}),
      size: const Size(390, 540),
      scale: 2,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Notes'),
      'Retained validation draft',
    );
    final notesController = tester
        .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
        .controller!;
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final focusBefore = FocusManager.instance.primaryFocus;
    final list = find.byKey(const ValueKey('event-editor-form-list'));
    await tester.drag(list, const Offset(0, -800));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)).first,
    );
    final position = scroll.position.pixels;
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Save event'));
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(scroll.position.pixels, closeTo(position, 1));
        expect(FocusManager.instance.primaryFocus, same(focusBefore));
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
    expect(controller.events, isEmpty);
    expect(notesController.text, 'Retained validation draft');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
