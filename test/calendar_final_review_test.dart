import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/calendar_week_view.dart';
import 'package:life_manager/features/calendar/calendar_day_view.dart';
import 'package:life_manager/features/calendar/timeline_grid.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/recurring_event_move_dialog.dart';

void main() {
  late AppDatabase db;
  late LifeRepository repo;
  late AppController app;
  late CalendarInteractionController interaction;
  const config = CalendarAppearanceConfiguration(initialScrollHour: 0);
  final monday = DateTime(2026, 11, 16);
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LifeRepository(db);
    app = AppController(repo);
    await app.refresh();
    interaction = CalendarInteractionController(config: config);
  });
  tearDown(() async {
    interaction.dispose();
    await db.close();
  });
  CalendarItem item(FixedEvent e) => CalendarItem(
    id: e.id,
    title: e.title,
    kind: CalendarItemKind.event,
    event: e,
    startsAt: e.startsAt.toLocal(),
    endsAt: e.endsAt.toLocal(),
  );
  Future<FixedEvent> event({EventRepeat? repeat}) => repo.addEvent(
    EventDraft(
      title: 'Review event',
      startsAt: DateTime(2026, 11, 16, 10),
      endsAt: DateTime(2026, 11, 16, 11),
      repeat: repeat,
    ),
  );
  void move(FixedEvent e, DateTime day, double y) {
    interaction.startMove(
      item: item(e),
      dayDate: monday,
      pointerLocal: const Offset(100, 600),
      pointerTimelineY: 600,
    );
    interaction.updatePointer(Offset(200, y), day, y);
  }

  test(
    'translate every selected weekday even when target was selected',
    () async {
      final master = await event(
        repeat: const EventRepeat(
          kind: EventRepeatKind.weekdays,
          weekdays: {1, 3},
        ),
      );
      final rule = interaction.calculateProposedSeriesRepeat(
        master: master,
        originStart: DateTime(2026, 11, 16, 10),
        proposedStart: DateTime(2026, 11, 18, 10),
      );
      expect(rule!.weekdays, {3, 5});
    },
  );
  test('no-change commit releases guard for the next gesture', () async {
    final e = await event();
    move(e, monday, 600);
    expect(await interaction.commit(app), isNull);
    move(e, monday, 660);
    expect(await interaction.commit(app), isNotNull);
    expect((await repo.events()).single.startsAt.toLocal().hour, 11);
  });
  test('explicit cancel during navigation aborts without history', () async {
    final e = await event();
    move(e, DateTime(2026, 11, 17), 660);
    interaction.beginNavigation();
    interaction.cancel();
    expect(interaction.activeItem, isNull);
    expect(interaction.hasPendingChange, isFalse);
    expect(interaction.undoCount, 0);
  });
  test('series move cannot detach existing cancelled occurrence', () async {
    final e = await event(
      repeat: const EventRepeat(kind: EventRepeatKind.weekly),
    );
    final occurrences = await repo.eventOccurrences('2026-11-16', '2026-11-30');
    await repo.setEventOccurrenceCancelled(occurrences[1], true);
    move(occurrences.first, DateTime(2026, 11, 18), 600);
    final result = await interaction.commit(
      app,
      scope: CalendarRecurringMoveScope.entireSeries,
    );
    expect(result, isNotNull);
    expect(
      (await repo.events()).single.startsAt.toLocal(),
      DateTime(2026, 11, 18, 10),
    );
    expect(await repo.eventOccurrences('2026-11-23', '2026-11-23'), isEmpty);
    expect(
      (await repo.eventOccurrences(
        '2026-11-25',
        '2026-11-25',
      )).single.cancelled,
      isTrue,
    );
  });

  test('series move rejects historical generation with StateError', () async {
    final e = await event(
      repeat: const EventRepeat(kind: EventRepeatKind.weekly),
    );
    // Mark as having a separate historical generation boundary
    await db.customStatement(
      "UPDATE fixed_events SET active_through_date='2026-11-20' WHERE id=?",
      [e.id],
    );
    final masterWithHistory = (await repo.events()).single;
    move(masterWithHistory, DateTime(2026, 11, 18), 600);
    await expectLater(
      interaction.commit(app, scope: CalendarRecurringMoveScope.entireSeries),
      throwsStateError,
    );
    expect((await repo.events()).single.startsAt, e.startsAt);
  });

  for (final dayView in [false, true]) {
    for (final scenario in [
      (name: 'forward', back: false, pages: 1),
      (name: 'backward', back: true, pages: 1),
      (name: 'two pages', back: false, pages: 2),
    ]) {
      for (final cancel in [false, true]) {
        testWidgets(
          '${dayView ? 'day' : 'week'} ${scenario.name} pointer survives edge paging and ${cancel ? 'cancels' : 'commits once'}',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1280, 1700));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final startDay = dayView || scenario.back ? 16 : 22;
            var saved = await repo.addEvent(
              EventDraft(
                title: 'Edge resize',
                startsAt: DateTime(2026, 11, startDay, scenario.back ? 10 : 20),
                endsAt: DateTime(2026, 11, startDay, scenario.back ? 12 : 22),
              ),
            );
            await db.customStatement(
              "UPDATE sync_capture_context SET workspace_id='review',account_id='review',device_id='review',capture_enabled=1 WHERE id=1",
            );
            var visible = DateTime(2026, 11, 16);
            var pages = 0;
            late StateSetter rebuild;
            void navigate(int direction) {
              interaction.beginNavigation();
              pages++;
              rebuild(
                () => visible = DateTime(
                  visible.year,
                  visible.month,
                  visible.day + direction * (dayView ? 1 : 7),
                ),
              );
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => interaction.endNavigation(),
              );
            }

            Future<void> finish() async {
              await interaction.commit(app);
              saved = (await repo.events()).single;
              rebuild(() {});
            }

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      rebuild = setState;
                      if (dayView)
                        return CalendarDayView(
                          dayDate: visible,
                          items: [item(saved)],
                          config: config,
                          interactionController: interaction,
                          onItemTap: (_) {},
                          onSlotSecondaryTap: (_, __) {},
                          onNavigateDay: navigate,
                          onInteractionFinished: finish,
                        );
                      return CalendarWeekView(
                        weekStart: visible,
                        config: config,
                        interactionController: interaction,
                        itemsByDay: {
                          for (var i = 0; i < 7; i++)
                            DateTime(
                              visible.year,
                              visible.month,
                              visible.day + i,
                            ): [
                              item(saved),
                            ],
                        },
                        onItemTap: (_) {},
                        onSlotSecondaryTap: (_, __) {},
                        onDayHeaderTap: (_) {},
                        onNavigateWeek: navigate,
                        onInteractionFinished: finish,
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final columns = find.byType(TimelineDayColumn);
            final last = tester.getRect(
              scenario.back ? columns.first : columns.last,
            );
            final gesture = await tester.startGesture(
              tester.getCenter(
                find.byTooltip(
                  scenario.back
                      ? 'Drag to adjust start time'
                      : 'Drag to adjust end time',
                ),
              ),
            );
            await gesture.moveBy(const Offset(0, 20));
            await gesture.moveTo(
              dayView
                  ? Offset(
                      last.center.dx,
                      scenario.back ? last.top + 2 : last.bottom - 2,
                    )
                  : Offset(
                      scenario.back ? last.left + 2 : last.right - 2,
                      last.top + (scenario.back ? 600 : 1320),
                    ),
            );
            await tester.pump(const Duration(milliseconds: 450));
            await tester.pump();
            expect(pages, 1);
            expect(interaction.activeItem, isNotNull);
            expect(interaction.undoCount, 0);
            expect(
              (await repo.events()).single.endsAt.toLocal(),
              DateTime(2026, 11, startDay, scenario.back ? 12 : 22),
            );
            await tester.pump(const Duration(seconds: 1));
            expect(
              pages,
              1,
              reason: 'stationary pointer must not run through pages',
            );
            if (scenario.pages == 2) {
              final center = tester.getRect(columns.at(dayView ? 0 : 3));
              await gesture.moveTo(Offset(center.center.dx, center.top + 600));
              await tester.pump();
              final edge = tester.getRect(columns.last);
              await gesture.moveTo(
                dayView
                    ? Offset(edge.center.dx, edge.bottom - 2)
                    : Offset(edge.right - 2, edge.top + 1320),
              );
              await tester.pump(const Duration(milliseconds: 450));
              await tester.pump();
              expect(pages, 2);
            }
            final nextColumn = tester.getRect(
              columns.at(
                dayView
                    ? 0
                    : scenario.back
                    ? 5
                    : 1,
              ),
            );
            await gesture.moveTo(
              Offset(
                nextColumn.center.dx,
                nextColumn.top + (scenario.back ? 1080 : 180),
              ),
            );
            await tester.pump();
            if (cancel) {
              await gesture.cancel();
            } else {
              await gesture.up();
            }
            await tester.pumpAndSettle();
            final persisted = (await repo.events()).single;
            expect(
              persisted.startsAt.toLocal(),
              scenario.back && !cancel
                  ? DateTime(2026, 11, dayView ? 15 : 14, 18)
                  : DateTime(2026, 11, startDay, scenario.back ? 10 : 20),
            );
            expect(
              persisted.endsAt.toLocal(),
              scenario.back || cancel
                  ? DateTime(2026, 11, startDay, scenario.back ? 12 : 22)
                  : DateTime(
                      2026,
                      11,
                      dayView ? 16 + scenario.pages : 17 + 7 * scenario.pages,
                      3,
                    ),
            );
            final journal = await db
                .customSelect(
                  "SELECT COUNT(*) AS n FROM sync_journal WHERE entity='fixed_events'",
                )
                .getSingle();
            expect(journal.read<int>('n'), cancel ? 0 : 1);
            expect(interaction.undoCount, cancel ? 0 : 1);
            expect(interaction.gestureKind, CalendarGestureKind.none);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'recurring completion is single-flight and Escape cancels the dialog',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await event(repeat: const EventRepeat(kind: EventRepeatKind.weekly));
      final occurrence = (await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-16',
      )).single;
      await app.refresh();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => app)],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: monday,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(CalendarView));
      final CalendarInteractionController current = state.interactionController;
      current.startMove(
        item: item(occurrence),
        dayDate: monday,
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600,
      );
      current.updatePointer(
        const Offset(200, 600),
        DateTime(2026, 11, 18),
        600,
      );
      final Future<void> first = state.handleInteractionFinished();
      current.startMove(
        item: item(occurrence),
        dayDate: monday,
        pointerLocal: Offset.zero,
        pointerTimelineY: 0,
      );
      expect(
        current.proposedStartsAt,
        DateTime(2026, 11, 18, 10),
        reason: 'A pending scope choice cannot be replaced by another gesture',
      );
      await state.handleInteractionFinished();
      await tester.pumpAndSettle();
      expect(find.byType(RecurringEventMoveDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await first;
      expect(current.gestureKind, CalendarGestureKind.none);
      expect(current.undoCount, 0);
      expect(
        (await repo.events()).single.startsAt.toLocal(),
        DateTime(2026, 11, 16, 10),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recurrence confirmation fits short narrow enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final master = await event(
      repeat: const EventRepeat(
        kind: EventRepeatKind.weekdays,
        weekdays: {1, 3},
        untilDate: '2027-03-31',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => RecurringEventMoveDialog(
                  event: master,
                  master: master,
                  originStart: master.startsAt.toLocal(),
                  targetStart: DateTime(2026, 11, 17, 10),
                  interactionController: interaction,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('2027-03-31'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });
  test(
    'series confirmation uses its approved revision and refuses stale data',
    () async {
      final original = await event(
        repeat: const EventRepeat(kind: EventRepeatKind.weekly),
      );
      await repo.updateEvent(
        original,
        EventDraft(
          title: 'Edited elsewhere',
          startsAt: original.startsAt,
          endsAt: original.endsAt,
          repeat: original.repeat,
        ),
      );
      move(original, DateTime(2026, 11, 18), 600);
      await expectLater(
        interaction.commit(
          app,
          scope: CalendarRecurringMoveScope.entireSeries,
          approvedSeriesMaster: original,
        ),
        throwsStateError,
      );
      expect((await repo.events()).single.title, 'Edited elsewhere');
      expect(interaction.undoCount, 0);
    },
  );
  test('series history refuses to reverse a later recurrence edit', () async {
    final original = await event(
      repeat: const EventRepeat(kind: EventRepeatKind.weekly),
    );
    move(original, DateTime(2026, 11, 18), 600);
    await interaction.commit(
      app,
      scope: CalendarRecurringMoveScope.entireSeries,
    );
    final moved = (await repo.events()).single;
    await repo.updateEvent(
      moved,
      EventDraft(
        title: moved.title,
        startsAt: moved.startsAt,
        endsAt: moved.endsAt,
        repeat: const EventRepeat(kind: EventRepeatKind.daily),
      ),
    );
    await expectLater(interaction.undo(app), throwsStateError);
    expect((await repo.events()).single.repeat!.kind, EventRepeatKind.daily);
    expect(interaction.undoCount, 1);
  });
  for (final recurring in [false, true]) {
    test(
      'off-viewport history survives month-window change recurring=$recurring',
      () async {
        final original = await event(
          repeat: recurring
              ? const EventRepeat(kind: EventRepeatKind.weekly)
              : null,
        );
        final dragged = recurring
            ? (await repo.eventOccurrences('2026-11-16', '2026-11-16')).single
            : original;
        interaction.startResizeBottom(
          item: item(dragged),
          dayDate: monday,
          pointerLocal: const Offset(100, 660),
          pointerTimelineY: 660,
        );
        interaction.updatePointer(
          const Offset(200, 180),
          DateTime(2026, 12, 3),
          180,
        );
        await interaction.commit(app);
        await app.ensureRecurringMonth(DateTime(2027, 2, 1));
        await interaction.undo(app);
        await interaction.redo(app);
        final loaded = await repo.eventOccurrences('2026-12-03', '2026-12-03');
        final restored = loaded.singleWhere(
          (e) => e.id == original.id && e.nominalDate == dragged.nominalDate,
        );
        expect(restored.endsAt.toLocal(), DateTime(2026, 12, 3, 3));
        expect(await repo.events(), hasLength(1));
      },
    );
  }
  testWidgets('narrow week resize handle wins over horizontal scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var saved = await event();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, rebuild) => CalendarWeekView(
              weekStart: monday,
              config: config,
              interactionController: interaction,
              itemsByDay: {
                monday: [item(saved)],
              },
              onItemTap: (_) {},
              onSlotSecondaryTap: (_, __) {},
              onDayHeaderTap: (_) {},
              onInteractionFinished: () async {
                await interaction.commit(app);
                saved = (await repo.events()).single;
                rebuild(() {});
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = tester.getRect(find.byType(TimelineDayColumn).at(1));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('Drag to adjust end time')),
    );
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveTo(Offset(target.center.dx, target.top + 600));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(saved.endsAt.toLocal(), DateTime(2026, 11, 17, 10));
    expect(interaction.undoCount, 1);
  });
  testWidgets('explicit cancellation stops captured resize auto-scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scroller = ScrollController();
    addTearDown(scroller.dispose);
    final e = await event();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroller,
            child: SizedBox(
              height: 1440,
              child: TimelineDayColumn(
                dayDate: monday,
                items: [item(e)],
                config: config,
                interactionController: interaction,
                scrollController: scroller,
                onItemTap: (_) {},
                onSlotSecondaryTap: (_, __) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('Drag to adjust end time')),
    );
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveTo(const Offset(100, 790));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scroller.offset, greaterThan(0));
    interaction.cancel();
    final stopped = scroller.offset;
    await tester.pump(const Duration(milliseconds: 200));
    expect(scroller.offset, stopped);
    await gesture.moveTo(const Offset(100, 792));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scroller.offset, stopped);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(interaction.undoCount, 0);
  });
}
