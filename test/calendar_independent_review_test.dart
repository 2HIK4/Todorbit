import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_day_view.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_layout_engine.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/calendar_week_view.dart';
import 'package:life_manager/features/calendar/timeline_grid.dart';

void main() {
  late AppDatabase db;
  late LifeRepository repo;
  late AppController app;
  const config = CalendarAppearanceConfiguration(initialScrollHour: 0);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LifeRepository(db);
    app = AppController(repo);
    await app.refresh();
  });
  tearDown(() async {
    await db.close();
  });

  CalendarItem eventItem(FixedEvent event) => CalendarItem(
    id: event.id,
    title: event.title,
    kind: CalendarItemKind.event,
    startsAt: event.startsAt.toLocal(),
    endsAt: event.endsAt.toLocal(),
    event: event,
  );

  for (final scenario in [
    (
      name: 'multiple columns',
      start: DateTime(2026, 11, 16, 9),
      end: DateTime(2026, 11, 16, 11),
      target: DateTime(2026, 11, 19, 14),
      top: false,
      segments: 4,
    ),
    (
      name: 'backward',
      start: DateTime(2026, 11, 18, 10),
      end: DateTime(2026, 11, 18, 12),
      target: DateTime(2026, 11, 17, 18),
      top: true,
      segments: 2,
    ),
  ]) {
    testWidgets('pointer resize ${scenario.name} saves all ordinary segments', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final created = await repo.addEvent(
        EventDraft(
          title: 'Pointer span',
          startsAt: scenario.start,
          endsAt: scenario.end,
        ),
      );
      var saved = created;
      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, refresh) => CalendarWeekView(
                weekStart: DateTime(2026, 11, 16),
                config: config,
                interactionController: interaction,
                itemsByDay: {
                  for (var i = 0; i < 7; i++)
                    DateTime(2026, 11, 16 + i): [eventItem(saved)],
                },
                onItemTap: (_) {},
                onSlotSecondaryTap: (_, _) {},
                onDayHeaderTap: (_) {},
                onInteractionFinished: () async {
                  await interaction.commit(app);
                  saved = (await repo.events()).single;
                  refresh(() {});
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final targetRect = tester.getRect(
        find.byType(TimelineDayColumn).at(scenario.target.day - 16),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byTooltip(
            scenario.top
                ? 'Drag to adjust start time'
                : 'Drag to adjust end time',
          ),
        ),
      );
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveTo(
        Offset(
          targetRect.center.dx,
          targetRect.top + scenario.target.hour * 60,
        ),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(saved.id, created.id);
      expect(
        saved.startsAt.toLocal(),
        scenario.top ? scenario.target : scenario.start,
      );
      expect(
        saved.endsAt.toLocal(),
        scenario.top ? scenario.end : scenario.target,
      );
      expect(find.text('Pointer span'), findsNWidgets(scenario.segments));
      expect(interaction.undoCount, 1);
      expect(await repo.events(), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'pointer resize crosses columns, saves segments, cancels and undoes once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final event = await repo.addEvent(
        EventDraft(
          title: 'Overnight workshop',
          startsAt: DateTime(2026, 11, 16, 20),
          endsAt: DateTime(2026, 11, 16, 22),
        ),
      );
      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);
      var saved = event;
      late StateSetter refresh;
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                refresh = setState;
                return CalendarWeekView(
                  weekStart: DateTime(2026, 11, 16),
                  config: config,
                  interactionController: interaction,
                  itemsByDay: {
                    for (var i = 0; i < 7; i++)
                      DateTime(2026, 11, 16 + i): [eventItem(saved)],
                  },
                  onItemTap: (_) => opens++,
                  onSlotSecondaryTap: (_, _) {},
                  onDayHeaderTap: (_) {},
                  onInteractionFinished: () async {
                    await interaction.commit(app);
                    saved = (await repo.events()).single;
                    refresh(() {});
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final columns = find.byType(TimelineDayColumn);
      final monday = tester.getRect(columns.at(0));
      final tuesday = tester.getRect(columns.at(1));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Drag to adjust end time')),
      );
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveTo(Offset(tuesday.center.dx, tuesday.top + 180));
      await tester.pump();
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 17, 3));
      expect(interaction.undoCount, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(saved.id, event.id);
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 17, 3));
      expect(await repo.events(), hasLength(1));
      expect(interaction.undoCount, 1);
      expect(find.text('Overnight workshop'), findsNWidgets(2));
      expect(find.text('20:00 – 24:00 →'), findsOneWidget);
      expect(find.text('← 00:00 – 03:00'), findsOneWidget);
      expect(find.byTooltip('Drag to adjust start time'), findsOneWidget);
      expect(find.byTooltip('Drag to adjust end time'), findsOneWidget);
      await tester.tapAt(Offset(tuesday.center.dx, tuesday.top + 90));
      expect(opens, 1);
      final cancel = await tester.startGesture(
        tester.getCenter(find.byTooltip('Drag to adjust start time')),
      );
      await cancel.moveBy(const Offset(0, -20));
      await cancel.moveTo(Offset(tuesday.center.dx, tuesday.top + 30));
      await cancel.cancel();
      await tester.pumpAndSettle();
      expect(interaction.gestureKind, CalendarGestureKind.none);
      expect(interaction.undoCount, 1);
      expect((await repo.events()).single.endsAt, saved.endsAt);
      await interaction.undo(app);
      saved = (await repo.events()).single;
      refresh(() {});
      await tester.pumpAndSettle();
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 16, 22));
      expect(find.text('Overnight workshop'), findsOneWidget);
      await interaction.redo(app);
      saved = (await repo.events()).single;
      refresh(() {});
      await tester.pumpAndSettle();
      expect(find.text('Overnight workshop'), findsNWidgets(2));
      expect(monday.height, tuesday.height);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'master move never silently replaces or collapses repeat weekdays',
    () async {
      final event = await repo.addEvent(
        EventDraft(
          title: 'Two lectures',
          startsAt: DateTime(2026, 11, 16, 10),
          endsAt: DateTime(2026, 11, 16, 11),
          repeat: const EventRepeat(
            kind: EventRepeatKind.weekdays,
            weekdays: {1, 3},
          ),
        ),
      );
      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);
      interaction.startDateDrag(
        item: eventItem(event),
        originDate: DateTime(2026, 11, 16),
      );
      interaction.updatePointer(Offset.zero, DateTime(2026, 11, 17));
      await expectLater(interaction.commit(app), throwsArgumentError);
      expect((await repo.events()).single.repeat!.weekdays, {1, 3});
      expect(interaction.undoCount, 0);
      interaction.startDateDrag(
        item: eventItem(event),
        originDate: DateTime(2026, 11, 16),
      );
      interaction.updatePointer(Offset.zero, DateTime(2026, 11, 18));
      await interaction.commit(app);
      expect((await repo.events()).single.repeat!.weekdays, {1, 3});
      await interaction.undo(app);
      expect(
        (await repo.events()).single.startsAt.toLocal(),
        DateTime(2026, 11, 16, 10),
      );
      await interaction.redo(app);
      expect((await repo.events()).single.repeat!.weekdays, {1, 3});
    },
  );

  test('contrast fallback chooses the stronger black or white on midtones', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.purple).copyWith(
      onSurface: const Color(0xFF888888),
      onSurfaceVariant: const Color(0xFF888888),
    );
    for (var channel = 0; channel <= 255; channel++) {
      final bg = Color.fromARGB(255, channel, channel, channel);
      for (final primary in [true, false]) {
        final fg = TimelineDayColumn.contrastAwareTextColor(
          background: bg,
          scheme: scheme,
          isPrimary: primary,
        );
        expect(
          TimelineDayColumn.calculateContrastRatio(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'gray $channel, primary=$primary',
        );
      }
    }
  });

  test('timeline rows use civil hours including the following midnight', () {
    const engine = CalendarLayoutEngine(config: config);
    final day = DateTime(2026, 11, 16);
    expect(engine.timeToY(DateTime(2026, 11, 16, 10, 30), day), 630);
    expect(engine.timeToY(DateTime(2026, 11, 17), day), 1440);
    expect(
      engine.yToTime(1440, day, allowEndBoundary: true),
      DateTime(2026, 11, 17),
    );
  });

  for (final osReduced in [false, true]) {
    testWidgets(
      'time zoom respects ${osReduced ? 'OS' : 'app'} reduced motion',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        if (!osReduced) {
          await app.saveCustomization(
            app.customization.copyWith(reducedMotion: true),
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appControllerProvider.overrideWith((ref) => app)],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: osReduced),
                child: child!,
              ),
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
        await tester.tap(find.byTooltip('Zoom in time slots'));
        await tester.pump();
        expect(
          tester
              .widget<TimelineDayColumn>(find.byType(TimelineDayColumn).first)
              .config
              .hourHeight,
          75,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final kind in [EventRepeatKind.monthly, EventRepeatKind.yearly]) {
    test(
      'master $kind date edit keeps rule, identity, duration and history',
      () async {
        final event = await repo.addEvent(
          EventDraft(
            title: 'Periodic review',
            startsAt: DateTime(2026, 11, 16, 10),
            endsAt: DateTime(2026, 11, 16, 11, 30),
            repeat: EventRepeat(
              kind: kind,
              interval: 2,
              untilDate: '2029-12-31',
            ),
          ),
        );
        final interaction = CalendarInteractionController(config: config);
        addTearDown(interaction.dispose);
        interaction.startDateDrag(
          item: eventItem(event),
          originDate: DateTime(2026, 11, 16),
        );
        interaction.updatePointer(Offset.zero, DateTime(2026, 11, 18));
        await interaction.commit(app);
        var saved = (await repo.events()).single;
        expect(saved.id, event.id);
        expect(saved.repeat!.kind, kind);
        expect(saved.repeat!.interval, 2);
        expect(saved.repeat!.untilDate, '2029-12-31');
        expect(
          saved.endsAt.difference(saved.startsAt),
          const Duration(minutes: 90),
        );
        await interaction.undo(app);
        expect((await repo.events()).single.startsAt, event.startsAt);
        await interaction.redo(app);
        saved = (await repo.events()).single;
        expect(saved.startsAt.toLocal(), DateTime(2026, 11, 18, 10));
      },
    );
  }

  test('occurrence exception with inherited repeat journals one identity and survives reload', () async {
    final event = await repo.addEvent(
      EventDraft(
        title: 'Weekly',
        startsAt: DateTime(2026, 11, 16, 10),
        endsAt: DateTime(2026, 11, 16, 11),
        repeat: const EventRepeat(
          kind: EventRepeatKind.weekdays,
          weekdays: {1, 3},
        ),
      ),
    );
    final occurrence = (await repo.eventOccurrences(
      '2026-11-16',
      '2026-11-16',
    )).single;
    await db.customStatement(
      "UPDATE sync_capture_context SET workspace_id='test',account_id='test',device_id='test',capture_enabled=1 WHERE id=1",
    );
    await repo.updateEventOccurrence(
      occurrence,
      EventDraft(
        title: occurrence.title,
        startsAt: DateTime(2026, 11, 17, 22),
        endsAt: DateTime(2026, 11, 19, 3),
        repeat: occurrence.repeat,
      ),
    );
    final projected = await LifeRepository(db)
        .eventOccurrences('2026-11-16', '2026-11-22');
    expect(await repo.events(), hasLength(1));
    expect((await repo.events()).single.repeat!.weekdays, {1, 3});
    expect(projected, hasLength(2));
    final moved = projected.singleWhere((e) => e.nominalDate == '2026-11-16');
    expect(moved.id, event.id);
    expect(moved.startsAt.toLocal(), DateTime(2026, 11, 17, 22));
    expect(moved.endsAt.toLocal(), DateTime(2026, 11, 19, 3));
    final journal = await db
        .customSelect(
          "SELECT entity,after_json FROM sync_journal WHERE entity='event_occurrence_changes'",
        )
        .get();
    expect(journal, hasLength(1));
    expect(journal.single.read<String>('after_json'), contains('2026-11-16'));
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'rendered timed text contrasts on translucent category cards ($brightness)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final interaction = CalendarInteractionController(config: config);
        addTearDown(interaction.dispose);
        final theme = ThemeData(brightness: brightness);
        for (final cancelled in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    height: 1440,
                    child: TimelineDayColumn(
                      dayDate: DateTime(2026, 11, 16),
                      config: config,
                      interactionController: interaction,
                      onItemTap: (_) {},
                      onSlotSecondaryTap: (_, _) {},
                      items: [
                        CalendarItem(
                          id: 'tinted',
                          title: 'Tinted card',
                          kind: CalendarItemKind.event,
                          startsAt: DateTime(2026, 11, 16, 3),
                          endsAt: DateTime(2026, 11, 16, 5),
                          isCancelled: cancelled,
                          colorValue: 0x44777777,
                          detailsText: 'Location: C3015',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final background =
              (tester
                          .widget<Container>(
                            find
                                .ancestor(
                                  of: find.text('Tinted card'),
                                  matching: find.byWidgetPredicate(
                                    (w) =>
                                        w is Container &&
                                        w.decoration is BoxDecoration,
                                  ),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration)
                  .color!;
          expect(background.a, 1);
          for (final label in ['Tinted card', 'Location: C3015']) {
            final color = tester.widget<Text>(find.text(label)).style!.color!;
            expect(color.a, 1);
            expect(
              TimelineDayColumn.calculateContrastRatio(color, background),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
      },
    );
    testWidgets('all-day metadata is visible and contrasting ($brightness)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);
      final theme = ThemeData(brightness: brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: CalendarDayView(
              dayDate: DateTime(2026, 11, 16),
              config: config,
              interactionController: interaction,
              items: [
                CalendarItem(
                  id: 'all-day',
                  title: 'Conference',
                  kind: CalendarItemKind.event,
                  allDay: true,
                  colorValue: 0x66449922,
                  detailsText: 'Location: C3015',
                ),
              ],
              onItemTap: (_) {},
              onSlotSecondaryTap: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Location: C3015', findRichText: true),
        findsWidgets,
      );
      final metadata = tester.widget<Text>(find.text('Location: C3015'));
      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Location: C3015'),
              matching: find.byType(Container),
            )
            .first,
      );
      final background = (card.decoration! as BoxDecoration).color!;
      expect(background.a, 1);
      expect(
        TimelineDayColumn.calculateContrastRatio(
          metadata.style!.color!,
          background,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'time zoom animates slot geometry and preserves the top time anchor',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => app)],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: DateTime(2026, 11, 16),
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester
          .widget<TimelineDayColumn>(find.byType(TimelineDayColumn).first)
          .config
          .hourHeight;
      final scrollable = tester.state<ScrollableState>(
        find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      final topHour = scrollable.position.pixels / before;
      await tester.tap(find.byTooltip('Zoom in time slots'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final mid = tester
          .widget<TimelineDayColumn>(find.byType(TimelineDayColumn).first)
          .config
          .hourHeight;
      expect(mid, greaterThan(before));
      expect(mid, lessThan(75));
      await tester.pumpAndSettle();
      final after = tester
          .widget<TimelineDayColumn>(find.byType(TimelineDayColumn).first)
          .config
          .hourHeight;
      expect(after, 75);
      expect(scrollable.position.pixels / after, closeTo(topHour, 0.02));
    },
  );
}
