import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/timeline_grid.dart';

void main() {
  group('Event Card Contrast & Readability Tests (CAL-02)', () {
    test('calculateContrastRatio meets WCAG mathematical standard', () {
      // Pure black on pure white has a 21:1 contrast ratio
      final blackWhiteRatio = TimelineDayColumn.calculateContrastRatio(Colors.black, Colors.white);
      expect(blackWhiteRatio, closeTo(21.0, 0.1));

      // Same color has a 1:1 contrast ratio
      final identicalRatio = TimelineDayColumn.calculateContrastRatio(Colors.white, Colors.white);
      expect(identicalRatio, closeTo(1.0, 0.01));
    });

    test('contrastAwareTextColor produces >= 4.5:1 contrast on diverse backgrounds in light & dark themes', () {
      final lightScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.light);
      final darkScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.dark);

      final sampleTints = [
        const Color(0xFFE8DEF8), // light lavender tint
        const Color(0xFF21005D), // dark purple tint
        const Color(0xFFFFD8E4), // soft pink tint
        const Color(0xFF003314), // dark forest green
        const Color(0xFFF9DEDC), // light red tint
        const Color(0xFF381E72), // medium purple
        const Color(0xFF004D40), // deep teal
        const Color(0xFFFFF3E0), // light orange
      ];

      for (final bg in sampleTints) {
        // Test primary text color
        final primaryLight = TimelineDayColumn.contrastAwareTextColor(
          background: bg,
          scheme: lightScheme,
          isPrimary: true,
        );
        final ratioPrimaryLight = TimelineDayColumn.calculateContrastRatio(primaryLight, bg);
        expect(
          ratioPrimaryLight,
          greaterThanOrEqualTo(4.5),
          reason: 'Primary text on $bg in light scheme must have >= 4.5:1 contrast',
        );

        // Test secondary text color (Location, metadata)
        final secondaryLight = TimelineDayColumn.contrastAwareTextColor(
          background: bg,
          scheme: lightScheme,
          isPrimary: false,
        );
        final ratioSecondaryLight = TimelineDayColumn.calculateContrastRatio(secondaryLight, bg);
        expect(
          ratioSecondaryLight,
          greaterThanOrEqualTo(4.5),
          reason: 'Secondary text on $bg in light scheme must have >= 4.5:1 contrast',
        );

        // Test in dark scheme
        final primaryDark = TimelineDayColumn.contrastAwareTextColor(
          background: bg,
          scheme: darkScheme,
          isPrimary: true,
        );
        final ratioPrimaryDark = TimelineDayColumn.calculateContrastRatio(primaryDark, bg);
        expect(
          ratioPrimaryDark,
          greaterThanOrEqualTo(4.5),
          reason: 'Primary text on $bg in dark scheme must have >= 4.5:1 contrast',
        );

        final secondaryDark = TimelineDayColumn.contrastAwareTextColor(
          background: bg,
          scheme: darkScheme,
          isPrimary: false,
        );
        final ratioSecondaryDark = TimelineDayColumn.calculateContrastRatio(secondaryDark, bg);
        expect(
          ratioSecondaryDark,
          greaterThanOrEqualTo(4.5),
          reason: 'Secondary text on $bg in dark scheme must have >= 4.5:1 contrast',
        );
      }
    });

    testWidgets('TimelineGrid renders Location secondary text with high contrast and hierarchy', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      final testDay = DateTime(2026, 11, 14);
      final item = CalendarItem(
        id: 'lecture-1',
        title: 'University Lecture',
        kind: CalendarItemKind.event,
        startsAt: DateTime(2026, 11, 14, 10, 0),
        endsAt: DateTime(2026, 11, 14, 11, 30),
        colorValue: const Color(0xFF6750A4).toARGB32(),
        detailsText: 'Location: C3015',
      );

      final controller = CalendarInteractionController(
        config: const CalendarAppearanceConfiguration(
          hourHeight: 60,
          snapMinutes: 15,
          startHour: 0,
          endHour: 24,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                height: 1440,
                child: TimelineDayColumn(
                  dayDate: testDay,
                  items: [item],
                  config: controller.config,
                  interactionController: controller,
                  onItemTap: (_) {},
                  onSlotSecondaryTap: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Location: C3015 text widget
      final locationFinder = find.text('Location: C3015');
      expect(locationFinder, findsOneWidget);

      final locationText = tester.widget<Text>(locationFinder);
      expect(locationText.style?.color, isNotNull);

      // Verify that the color is NOT the low-contrast scheme.outline
      final theme = ThemeData.light();
      expect(locationText.style?.color != theme.colorScheme.outline, isTrue);

      // Verify title is rendered with bold hierarchy
      final titleFinder = find.text('University Lecture');
      expect(titleFinder, findsOneWidget);
      final titleText = tester.widget<Text>(titleFinder);
      expect(titleText.style?.fontWeight, FontWeight.w600);
    });
  });
}
