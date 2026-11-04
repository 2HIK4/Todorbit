import 'dart:io';
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
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/settings/widget_settings_page.dart';
import 'package:life_manager/features/workspace/workspace.dart';

import 'test_privacy.dart';
import 'widget_settings_page_test.dart'
    show FixtureCompanion, MemoryWidgetConfigurations;

void main() {
  late AppDatabase database;
  late AppController controller;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/activation'),
          (_) async => null,
        );
    database = AppDatabase(NativeDatabase.memory());
    controller = AppController(LifeRepository(database));
    await controller.refresh();
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/activation'),
          null,
        );
    await database.close();
  });

  Future<void> open(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(900, 550),
    double scale = 2,
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
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          privacyOverride,
        ],
        child: RepaintBoundary(
          key: const ValueKey('high-use-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.dark, ThemePalette.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final output = Platform.environment['AUDIT_CAPTURE_DIR'];
    if (output == null) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('high-use-capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Today empty content and primary action fit a short enlarged window',
    (tester) async {
      await open(tester, const Workspace());
      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(FilledButton, 'New task').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.text('No tasks planned for today')).bottom,
        lessThan(550),
      );
      await capture(tester, 'today-empty-large');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'task completion semantics identify the task and completion state',
    (tester) async {
      final task = await controller.repository.addTask(
        TaskDraft(title: 'Read design notes'),
      );
      await controller.refresh();
      controller.navigate(WorkspaceView.all);
      final semantics = tester.ensureSemantics();
      await open(
        tester,
        const Workspace(),
        size: const Size(1280, 800),
        scale: 1,
      );
      expect(
        tester.getSemantics(find.byType(Checkbox).first).label,
        contains('Read design notes'),
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(
        (await controller.repository.tasks())
            .firstWhere((t) => t.id == task.id)
            .status,
        TaskStatus.completed,
      );
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets('Calendar mode labels remain whole at enlarged desktop text', (
    tester,
  ) async {
    await open(
      tester,
      CalendarView(
        onAddTask: (_) {},
        onTaskTap: (_) {},
        onSmartReschedule: () {},
      ),
    );
    for (final name in ['Day', 'Week', 'Month']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      expect(
        tester.getSize(find.text(name)).width,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01,
        ),
        reason: '$name should fit without breaking the word',
      );
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    final period = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('calendar-period-label')),
    );
    expect(
      period.size.width,
      greaterThanOrEqualTo(period.getMaxIntrinsicWidth(double.infinity) - 0.01),
      reason: 'The visible month and year must remain identifiable.',
    );
    await capture(tester, 'calendar-large');
    await tester.pumpWidget(const SizedBox());
  });

  for (final kind in ['tasks', 'calendar']) {
    testWidgets(
      '$kind widget customization keeps actions reachable at enlarged text',
      (tester) async {
        final store = MemoryWidgetConfigurations();
        await open(
          tester,
          SingleChildScrollView(
            child: WidgetSettingsPage(
              service: FixtureCompanion(),
              store: store,
            ),
          ),
          size: const Size(520, 650),
        );
        await tester.ensureVisible(find.text('Configure $kind widget'));
        await tester.tap(find.text('Configure $kind widget'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.widgetWithText(FilledButton, 'Apply').hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        await tester.pump();
        for (final label in ['Apply', 'Cancel', 'Apply to All Widgets']) {
          final bounds = tester.getRect(find.text(label));
          expect(bounds.top, greaterThanOrEqualTo(24));
          expect(bounds.bottom, lessThanOrEqualTo(626));
        }
        await capture(tester, 'widget-$kind-large');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(store.writes, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
