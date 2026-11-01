import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/features/settings/restore_confirmation_dialog.dart';
import 'package:life_manager/features/shared/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
        'restore warnings and fixed actions at $size in ${brightness.name}',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          bool? decision;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(
                brightness,
                brightness == Brightness.dark
                    ? ThemePalette.dark
                    : ThemePalette.light,
                android: true,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width == 360 ? 2 : 1.5),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      decision = await showDialog<bool>(
                        context: context,
                        builder: (_) => const RestoreConfirmationDialog(
                          backupLabel: 'Backup: Nov 2, 2026',
                          summary: '4 tasks, 2 events',
                          localWarning:
                              'Back up local changes before replacing them.',
                          details: 'Synthetic profile details',
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text('Back up local changes before replacing them.'),
            findsOneWidget,
          );
          expect(find.text('Synthetic profile details'), findsNothing);
          final action = tester.getRect(find.text('Confirm replacement'));
          expect(action.bottom, lessThan(size.height));
          expect(action.top, greaterThan(0));
          await tester.ensureVisible(find.text('Restore details'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Restore details'));
          await tester.pumpAndSettle();
          expect(find.text('Synthetic profile details'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(decision, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
