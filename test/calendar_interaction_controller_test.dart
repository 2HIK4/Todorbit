import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';

void main() {
  const config = CalendarAppearanceConfiguration(
    hourHeight: 60.0,
    snapMinutes: 15,
    minItemDurationMinutes: 15,
    dragThreshold: 4.0,
    startHour: 0,
    endHour: 24,
  );
  final day = DateTime(2026, 11, 10);

  group('CalendarInteractionController move & resize calculations', () {
    test('startMove and pointer movement updates proposed startsAt and endsAt', () {
      final controller = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: '1',
        title: 'Meeting',
        kind: CalendarItemKind.event,
        startsAt: DateTime(2026, 11, 10, 10, 0),
        endsAt: DateTime(2026, 11, 10, 11, 30), // 90 min
      );

      controller.startMove(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 600), // 10:00 is 600px
      );

      expect(controller.gestureKind, CalendarGestureKind.move);
      expect(controller.isDragging, isFalse);

      // Move down by 30 px (30 mins = 30px since hourHeight is 60)
      controller.updatePointer(const Offset(10, 630), day);

      expect(controller.isDragging, isTrue);
      expect(controller.proposedStartsAt!.hour, 10);
      expect(controller.proposedStartsAt!.minute, 30);
      expect(controller.proposedEndsAt!.hour, 12);
      expect(controller.proposedEndsAt!.minute, 0); // Preserves 90 min duration!
    });

    test('resizeTop modifies start time and keeps end time fixed', () {
      final controller = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: '1',
        title: 'Meeting',
        kind: CalendarItemKind.event,
        startsAt: DateTime(2026, 11, 10, 10, 0),
        endsAt: DateTime(2026, 11, 10, 11, 30),
      );

      controller.startResizeTop(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 600),
      );

      // Move down by 30 px -> start time moves to 10:30
      controller.updatePointer(const Offset(10, 630), day);

      expect(controller.proposedStartsAt!.hour, 10);
      expect(controller.proposedStartsAt!.minute, 30);
      expect(controller.proposedEndsAt!.hour, 11);
      expect(controller.proposedEndsAt!.minute, 30); // End time fixed!
    });

    test('resizeBottom modifies end time and keeps start time fixed', () {
      final controller = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: '1',
        title: 'Meeting',
        kind: CalendarItemKind.event,
        startsAt: DateTime(2026, 11, 10, 10, 0),
        endsAt: DateTime(2026, 11, 10, 11, 30),
      );

      controller.startResizeBottom(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 690), // 11:30 is 690px
      );

      // Move down by 30 px -> end time moves to 12:00
      controller.updatePointer(const Offset(10, 720), day);

      expect(controller.proposedStartsAt!.hour, 10);
      expect(controller.proposedStartsAt!.minute, 0); // Start time fixed!
      expect(controller.proposedEndsAt!.hour, 12);
      expect(controller.proposedEndsAt!.minute, 0);
    });

    test('cancel resets interaction state', () {
      final controller = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: '1',
        title: 'Meeting',
        kind: CalendarItemKind.event,
        startsAt: DateTime(2026, 11, 10, 10, 0),
        endsAt: DateTime(2026, 11, 10, 11, 0),
      );

      controller.startMove(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 600),
      );
      controller.updatePointer(const Offset(10, 660), day);
      expect(controller.isDragging, isTrue);

      controller.cancel();

      expect(controller.gestureKind, CalendarGestureKind.none);
      expect(controller.activeItem, isNull);
      expect(controller.isDragging, isFalse);
    });
  });
}
