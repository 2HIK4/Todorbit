import 'dart:io';
import 'dart:convert';
import 'dart:ui' show ImageByteFormat;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/mobile/mobile_calendar.dart';
import 'package:life_manager/features/settings/settings_transfer_dialog.dart';
import 'package:life_manager/features/workspace/trash_dialog.dart';

class _InvalidSettingsFile implements File {
  @override
  Future<bool> exists() async => true;
  @override
  Future<int> length() async => 14;
  @override
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      '{"categories":';
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late LifeRepository repo;
  late AppController controller;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LifeRepository(db);
    controller = AppController(repo);
    await controller.refresh();
  });
  tearDown(() async => db.close());

  Future<void> open(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 700),
    double scale = 2,
    bool dialog = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fontFile = File('C:/Windows/Fonts/segoeui.ttf');
    if (fontFile.existsSync()) {
      final font = FontLoader('Roboto');
      font.addFont(
        Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
      );
      await font.load();
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: RepaintBoundary(
          key: const ValueKey('populated-capture'),
          child: MaterialApp(
            theme: buildAppTheme(Brightness.dark, ThemePalette.dark),
            builder: (context, widget) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: widget!,
            ),
            home: Scaffold(
              body: dialog
                  ? Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => child,
                        ),
                        child: const Text('Open workflow'),
                      ),
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (dialog) {
      await tester.tap(find.text('Open workflow'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final output = Platform.environment['AUDIT_CAPTURE_DIR'];
    if (output == null) return;
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('populated-capture')),
          )
          .toImage();
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> seedCalendar() async {
    await repo.addEvent(
      EventDraft(
        title: 'Overnight preparation',
        startsAt: DateTime(2026, 11, 3, 23),
        endsAt: DateTime(2026, 11, 4, 1),
      ),
    );
    await repo.addEvent(
      EventDraft(
        title: 'Multi-day conference',
        startsAt: DateTime(2026, 11, 4),
        endsAt: DateTime(2026, 11, 7),
        allDay: true,
      ),
    );
    for (var i = 0; i < 8; i++) {
      await repo.addEvent(
        EventDraft(
          title: 'Overlapping project review $i',
          startsAt: DateTime(2026, 11, 4, 9, i * 3),
          endsAt: DateTime(2026, 11, 4, 11),
        ),
      );
    }
    await repo.addEvent(
      EventDraft(
        title: 'Daily recurring check-in',
        startsAt: DateTime(2026, 11, 4, 12),
        endsAt: DateTime(2026, 11, 4, 13),
        repeat: const EventRepeat(
          kind: EventRepeatKind.daily,
          untilDate: '2026-11-06',
        ),
      ),
    );
    await controller.refresh();
  }

  Widget calendar() => CalendarView(
    initialDate: DateTime(2026, 11, 4),
    onAddTask: (_) {},
    onTaskTap: (_) {},
    onSmartReschedule: () {},
  );

  testWidgets(
    'dense enlarged Week keeps weekday and populated entries readable',
    (tester) async {
      await seedCalendar();
      await open(tester, calendar(), size: const Size(800, 700));
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      final day = find.text('Wed 2026-11-04');
      await capture(tester, 'dense-week-before-or-after');
      expect(
        day,
        findsOneWidget,
        reason: 'Use the existing stacked week when compact columns fragment enlarged event titles.',
      );
      await tester.scrollUntilVisible(
        day,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('continued overnight events do not show a new late-night start', (
    tester,
  ) async {
    await seedCalendar();
    await open(tester, calendar(), size: const Size(800, 700));
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('Overnight preparation'), findsOneWidget);
    expect(find.text('Continues'), findsOneWidget);
    expect(find.text('All day'), findsOneWidget);
    await capture(tester, 'overnight-day');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mobile agenda identifies an overnight continuation', (
    tester,
  ) async {
    await seedCalendar();
    await open(
      tester,
      MobileCalendar(
        initialDay: DateTime(2026, 11, 4),
        openTask: (_) {},
        addTask: (_) {},
      ),
    );
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Continues until'), findsOneWidget);
    expect(find.text('Overnight preparation'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'mobile-overnight');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('invalid settings import leaves existing preferences intact', (
    tester,
  ) async {
    final before = controller.taskViewPreferences;
    await open(
      tester,
      SettingsTransferDialog(chooseImport: () async => _InvalidSettingsFile()),
      dialog: true,
    );
    await tester.tap(find.text('Import JSON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not import settings:'), findsOneWidget);
    expect(controller.taskViewPreferences, same(before));
    expect(find.text('Apply selected'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsTransferDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'long Trash confirmation is readable and cancellation preserves records',
    (tester) async {
      final name = List.filled(
        4,
        'Retain task history and linked research notes',
      ).join(' ');
      final task = await repo.addTask(TaskDraft(title: name));
      await repo.deleteTask(task.id);
      await controller.refresh();
      await open(tester, const ArchiveTrashDialog(), dialog: true);
      await tester.tap(find.text('Trash').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Permanently delete'));
      await tester.pumpAndSettle();
      final confirmation = find.widgetWithText(
        AlertDialog,
        'Permanently delete?',
      );
      await capture(tester, 'trash-long-confirmation');
      expect(
        find.descendant(
          of: confirmation,
          matching: find.byType(SingleChildScrollView),
        ),
        findsWidgets,
        reason:
            'All consequences for a long record name must remain reachable.',
      );
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.trashItems.single.id, task.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
