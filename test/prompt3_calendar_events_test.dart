import 'package:drift/drift.dart' show driftRuntimeOptions, Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/calendar_month_view.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:life_manager/features/shared/color_picker_dialog.dart';
import 'package:life_manager/features/shared/event_color_picker.dart';

import 'support/editor_disclosure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Prompt 3 | Calendar responsive display on narrow widths', () {
    testWidgets('month cells show meaningful items or clickable +N affordance on narrow desktop widths without disappearing or overflowing', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 15);
      final itemsByDay = <DateTime, List<CalendarItem>>{
        DateTime(2026, 11, 15): [
          CalendarItem(
            id: 'ev-1',
            title: 'Design Review Meeting',
            kind: CalendarItemKind.event,
            startsAt: DateTime(2026, 11, 15, 10),
            endsAt: DateTime(2026, 11, 15, 11),
          ),
          CalendarItem(
            id: 'ev-2',
            title: 'Engineering Standup',
            kind: CalendarItemKind.event,
            startsAt: DateTime(2026, 11, 15, 11, 30),
            endsAt: DateTime(2026, 11, 15, 12),
          ),
          CalendarItem(
            id: 'task-1',
            title: 'Complete schema audit',
            kind: CalendarItemKind.task,
          ),
        ],
        DateTime(2026, 11, 16): [
          CalendarItem(
            id: 'ev-3',
            title: 'Single Solo Event',
            kind: CalendarItemKind.event,
            startsAt: DateTime(2026, 11, 16, 14),
            endsAt: DateTime(2026, 11, 16, 15),
          ),
        ],
      };

      DateTime? tappedDay;

      try {
        // Test across narrow window widths: 420px, 520px, 680px
        for (final width in [420.0, 520.0, 680.0]) {
          await tester.binding.setSurfaceSize(Size(width, 500));
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  height: 500,
                  child: CalendarMonthView(
                    selectedDate: now,
                    firstWeekday: DateTime.monday,
                    itemsByDay: itemsByDay,
                    config: const CalendarAppearanceConfiguration(),
                    onItemTap: (_) {},
                    onDayTap: (date) => tappedDay = date,
                    onItemDroppedOnDate: (_, _) {},
                    onShowDay: (_) {},
                    onShowWeek: (_) {},
                    onAddEvent: (_) {},
                    onAddTask: (_) {},
                    onAddSession: (_) {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'No layout overflow at width $width');

          // The first scheduled item on Nov 15 must be visible and not hidden
          expect(find.text('Design Review Meeting'), findsOneWidget, reason: 'First item visible at width $width');

          // The solo event on Nov 16 must also be visible (never replaced with "+0 more")
          expect(find.text('Single Solo Event'), findsOneWidget, reason: 'Solo item visible at width $width');

          // Nov 15 has 3 items: it must display a clickable +N affordance (+2 or +2 more)
          final overflowFinder = find.byWidgetPredicate((widget) =>
              widget is Text &&
              (widget.data?.startsWith('+2') ?? false));
          expect(overflowFinder, findsOneWidget, reason: 'Clickable overflow affordance present');

          // Tapping the +N affordance triggers onDayTap with that date
          tappedDay = null;
          await tester.tap(overflowFinder);
          await tester.pumpAndSettle();
          expect(tappedDay, DateTime(2026, 11, 15));
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('calendar content filter updates visible month entries discoverably without overflow', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);

      // Create an event and a task on today
      final now = DateTime.now();
      await repo.addEvent(EventDraft(
        title: 'Team Sync Event',
        startsAt: DateTime(now.year, now.month, now.day, 10),
        endsAt: DateTime(now.year, now.month, now.day, 11),
      ));
      await repo.addTask(TaskDraft(
        title: 'Submit quarterly report',
        scheduledDate: localDate(now),
      ));
      controller.navigate(WorkspaceView.calendar);
      await controller.refresh();

      await tester.binding.setSurfaceSize(const Size(1000, 750));
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CalendarView(
                  onTaskTap: (_) {},
                  onSmartReschedule: () {},
                  onAddTask: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to month mode
        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // In Both mode, both event and task exist
        expect(find.text('Team Sync Event'), findsOneWidget);
        expect(find.text('Submit quarterly report'), findsOneWidget);

        // Switch to Tasks only
        await controller.setCalendarContent(CalendarContent.tasksOnly);
        await tester.pumpAndSettle();
        expect(find.text('Team Sync Event'), findsNothing);
        expect(find.text('Submit quarterly report'), findsOneWidget);

        // Switch to Events only
        await controller.setCalendarContent(CalendarContent.eventsOnly);
        await tester.pumpAndSettle();
        expect(find.text('Team Sync Event'), findsOneWidget);
        expect(find.text('Submit quarterly report'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });
  });

  group('Prompt 3 | Event Categories and Projects persistence', () {
    testWidgets('event add and edit assigns category and project, persisting to database', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final cat = await repo.addCategory('Work');
      final proj = await repo.addProject(cat.id, 'Mobile Redesign');
      final controller = AppController(repo);
      await controller.refresh();

      await tester.binding.setSurfaceSize(const Size(900, 750));
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: EventEditor(
                  initialDay: DateTime(2026, 11, 17),
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter event title
        await tester.enterText(
          find.widgetWithText(TextField, 'Title *'),
          'Kickoff Meeting',
        );

        // Expand 'Organization and appearance' section
        await expandEditorSection(
          tester,
          'Organization and appearance',
          editor: EventEditor,
        );

        // Open category selector and select 'Work'
        final catField = find.widgetWithText(AnchoredSelectField<String?>, 'Category');
        await tester.ensureVisible(catField);
        await tester.tap(catField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Work').last);
        await tester.pumpAndSettle();

        // Project selector is now enabled; select 'Mobile Redesign'
        final projField = find.widgetWithText(AnchoredSelectField<String?>, 'Project');
        await tester.ensureVisible(projField);
        await tester.tap(projField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mobile Redesign').last);
        await tester.pumpAndSettle();

        // Save event
        await tester.ensureVisible(find.text('Save event'));
        await tester.tap(find.text('Save event'));
        await tester.pumpAndSettle();

        // Verify event was persisted with categoryId and projectId
        final events = await repo.events();
        expect(events.length, 1);
        final saved = events.single;
        expect(saved.title, 'Kickoff Meeting');
        expect(saved.categoryId, cat.id);
        expect(saved.projectId, proj.id);

        // Raw SQLite row check: category_id and project_id columns must match
        final raw = await db.customSelect(
          'SELECT category_id, project_id FROM fixed_events WHERE id=?',
          variables: [Variable.withString(saved.id)],
        ).getSingle();
        expect(raw.read<String?>('category_id'), cat.id);
        expect(raw.read<String?>('project_id'), proj.id);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('creating a new category or project inside event editor immediately assigns it', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.refresh();

      await tester.binding.setSurfaceSize(const Size(900, 750));
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: EventEditor(
                  initialDay: DateTime(2026, 11, 17),
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Title *'),
          'New Org Event',
        );

        // Expand 'Organization and appearance' section
        await expandEditorSection(
          tester,
          'Organization and appearance',
          editor: EventEditor,
        );

        // Tap Category dropdown -> select "+ New Category"
        final catField = find.widgetWithText(AnchoredSelectField<String?>, 'Category');
        await tester.ensureVisible(catField);
        await tester.tap(catField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('+ New Category'));
        await tester.pumpAndSettle();

        // Dialog opens for Category name -> enter 'Fitness' and create
        await tester.enterText(find.widgetWithText(TextField, 'Category name'), 'Fitness');
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        // Category 'Fitness' must now be selected
        expect(find.text('Fitness'), findsOneWidget);

        // Tap Project dropdown -> select "+ New Project"
        final projField = find.widgetWithText(AnchoredSelectField<String?>, 'Project');
        await tester.ensureVisible(projField);
        await tester.tap(projField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('+ New Project'));
        await tester.pumpAndSettle();

        // Dialog opens for Project name -> enter 'Project Marathon' and create
        await tester.enterText(find.widgetWithText(TextField, 'Project name'), 'Project Marathon');
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        // Project 'Project Marathon' must now be selected
        expect(find.text('Project Marathon'), findsOneWidget);

        // Save event
        await tester.ensureVisible(find.text('Save event'));
        await tester.tap(find.text('Save event'));
        await tester.pumpAndSettle();

        final events = await repo.events();
        expect(events.length, 1);
        final saved = events.single;
        expect(saved.title, 'New Org Event');
        final fitnessCat = (await repo.categories()).firstWhere((c) => c.name == 'Fitness');
        final marathonProj = (await repo.projects()).firstWhere((p) => p.name == 'Project Marathon');
        expect(saved.categoryId, fitnessCat.id);
        expect(saved.projectId, marathonProj.id);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('old events without category or project remain valid with null assignments', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);

      // Insert event directly with null category and project
      final now = DateTime.now();
      final oldEvent = await repo.addEvent(EventDraft(
        title: 'Legacy Event Without Org',
        startsAt: now,
        endsAt: now.add(const Duration(hours: 1)),
        categoryId: null,
        projectId: null,
      ));

      expect(oldEvent.categoryId, isNull);
      expect(oldEvent.projectId, isNull);

      final controller = AppController(repo);
      await controller.refresh();

      await tester.binding.setSurfaceSize(const Size(900, 750));
      try {
        // Open in EventEditor
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: EventEditor(
                  event: oldEvent,
                  initialDay: now,
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expand 'Organization and appearance' section
        await expandEditorSection(
          tester,
          'Organization and appearance',
          editor: EventEditor,
        );

        // Category shows 'None / Inbox', Project shows 'None'
        expect(find.text('None / Inbox'), findsOneWidget);
        expect(find.text('None'), findsOneWidget);

        // Re-save without edits
        await tester.ensureVisible(find.text('Save event'));
        await tester.tap(find.text('Save event'));
        await tester.pumpAndSettle();

        final updated = (await repo.events()).singleWhere((e) => e.id == oldEvent.id);
        expect(updated.categoryId, isNull);
        expect(updated.projectId, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });
  });

  group('Prompt 3 | Color picker steady scroll and lifecycle', () {
    testWidgets('event color picker preserves scroll offset steadily during user scroll, chip selection and color change without snapping back', (
      tester,
    ) async {
      int? selectedColor;
      await tester.binding.setSurfaceSize(const Size(380, 520));

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    selectedColor = await chooseEventColor(context, 0xFF5365B5);
                  },
                  child: const Text('Open Color Picker'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Color Picker'));
        await tester.pumpAndSettle();

        // Find the SingleChildScrollView inside the color dialog
        final scrollFinder = find.byKey(const PageStorageKey('event_color_dialog_scroll'));
        expect(scrollFinder, findsOneWidget);

        // Initial scroll offset is 0
        final scrollable = tester.widget<SingleChildScrollView>(scrollFinder);
        final scrollController = scrollable.controller!;
        expect(scrollController.offset, 0.0);

        // User scrolls down by 140px using pointer drag
        await tester.drag(scrollFinder, const Offset(0, -140));
        await tester.pumpAndSettle();
        final scrolledOffset = scrollController.offset;
        expect(scrolledOffset, greaterThan(100.0), reason: 'User scrolled down');

        // Tap on 'Accent' ChoiceChip to switch palette
        await tester.tap(find.text('Accent'));
        await tester.pumpAndSettle();

        // Scroll offset must NOT snap back to 0.0 or previous initial position!
        expect(scrollController.offset, closeTo(scrolledOffset, 2.0),
            reason: 'Scroll offset must remain steady across palette choice switch');

        // Type into HEX color text field
        final hexField = find.widgetWithText(TextField, 'HEX color');
        await tester.ensureVisible(hexField);
        await tester.enterText(hexField, '#123456');
        await tester.pumpAndSettle();

        // Tap 'Use color' to confirm
        await tester.tap(find.text('Use color'));
        await tester.pumpAndSettle();

        expect(selectedColor, 0xFF123456, reason: 'Save behavior returns correct chosen color');

        // Test cancel behavior: open again and tap Cancel
        selectedColor = -1;
        await tester.tap(find.text('Open Color Picker'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(selectedColor, isNull, reason: 'Cancel behavior pops with null without mutating');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('color picker dialog keeps scroll steady across mouse wheel and touch scroll', (
      tester,
    ) async {
      Color? chosen;
      await tester.binding.setSurfaceSize(const Size(500, 320));

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    chosen = await showDialog<Color>(
                      context: context,
                      builder: (_) => const ColorPickerDialog(
                        title: 'Select Theme Accent',
                        initialColor: Colors.blue,
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final scrollFinder = find.byKey(const PageStorageKey('color_picker_dialog_scroll'));
        expect(scrollFinder, findsOneWidget);
        final scrollable = tester.widget<SingleChildScrollView>(scrollFinder);
        final scrollController = scrollable.controller!;

        // Scroll down to hex field
        final hex = find.widgetWithText(TextField, 'HEX color');
        await tester.ensureVisible(hex);
        await tester.pumpAndSettle();
        final offsetBeforeInput = scrollController.offset;
        expect(offsetBeforeInput, greaterThan(40.0));

        // Enter text which triggers setState
        await tester.enterText(hex, '#AABBCC');
        await tester.pumpAndSettle();

        // Confirm scroll offset did not jump back to 0 or snap back to initial position
        expect(scrollController.offset, greaterThan(200.0));

        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(chosen, const Color(0xFFAABBCC));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(null);
      }
    });
  });

  group('Prompt 3 | Month navigation flicker and prefetching', () {
    testWidgets('navigating adjacent months retains events in prefetch window without blank flicker', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);

      // Seed events across November and December 2026
      await repo.addEvent(EventDraft(
        title: 'November Gala',
        startsAt: DateTime(2026, 11, 10, 18),
        endsAt: DateTime(2026, 11, 10, 21),
      ));
      await repo.addEvent(EventDraft(
        title: 'December Holiday Party',
        startsAt: DateTime(2026, 12, 15, 19),
        endsAt: DateTime(2026, 12, 15, 22),
      ));

      // Ensure 3-month prefetch window centered on Nov 2026
      await controller.ensureRecurringMonth(DateTime(2026, 11, 1));
      controller.navigate(WorkspaceView.calendar);
      await controller.refresh();

      // Both November and December events must be loaded in controller.events
      expect(controller.events.any((e) => e.title == 'November Gala'), isTrue);
      expect(controller.events.any((e) => e.title == 'December Holiday Party'), isTrue);

      await tester.binding.setSurfaceSize(const Size(1000, 750));
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CalendarView(
                  initialDate: DateTime(2026, 11, 15),
                  onTaskTap: (_) {},
                  onSmartReschedule: () {},
                  onAddTask: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Month view
        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();

        // November Gala must be visible in November
        expect(find.text('November Gala'), findsOneWidget);

        // Fast forward to December: tap Next period button
        final nextButton = find.byTooltip('Next period');
        expect(nextButton, findsOneWidget);

        await tester.tap(nextButton);
        // Synchronously pump 1 frame (before any background async completion)
        await tester.pump();

        // December Holiday Party must be immediately visible without blank frame!
        expect(find.text('December Holiday Party'), findsOneWidget,
            reason: 'Prefetched adjacent month data displays with zero blank frame');

        // Navigate back to November
        final prevButton = find.byTooltip('Previous period');
        await tester.tap(prevButton);
        await tester.pump();

        // November Gala must be immediately visible
        expect(find.text('November Gala'), findsOneWidget,
            reason: 'Prefetched previous month data displays with zero blank frame');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('rapid back/forward clicks do not trigger race conditions or stale state', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.ensureRecurringMonth(DateTime(2026, 11, 1));
      controller.navigate(WorkspaceView.calendar);
      await controller.refresh();

      await tester.binding.setSurfaceSize(const Size(1000, 750));
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CalendarView(
                  initialDate: DateTime(2026, 11, 15),
                  onTaskTap: (_) {},
                  onSmartReschedule: () {},
                  onAddTask: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();

        final nextButton = find.byTooltip('Next period');
        // Click rapidly 5 times
        for (var i = 0; i < 5; i++) {
          await tester.tap(nextButton);
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final periodLabel = find.byKey(const ValueKey('calendar-period-label'));
        expect(periodLabel, findsOneWidget);
        // Selected date is April 2027 (Nov 2026 + 5 months)
        expect(find.text('April 2027'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });
  });
}
