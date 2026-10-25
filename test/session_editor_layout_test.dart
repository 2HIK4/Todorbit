import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/session_editor.dart';

void main() {
  testWidgets('new and edit session actions remain in a narrow enlarged form', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final task = await repo.addTask(
      const TaskDraft(title: 'A long task title for the session selector'),
    );
    final saved = await repo.addSession(
      SessionDraft(
        taskId: task.id,
        startsAt: DateTime.utc(2026, 10, 25, 10),
        endsAt: DateTime.utc(2026, 10, 25, 11),
      ),
    );
    final controller = AppController(repo);
    await controller.refresh();
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => controller)],
    );
    try {
      for (final brightness in Brightness.values) {
        for (final session in <WorkSession?>[null, saved]) {
          await tester.binding.setSurfaceSize(const Size(300, 600));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SessionEditor(
                    key: UniqueKey(),
                    session: session,
                    initialDay: DateTime(2026, 10, 25),
                    onClose: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final save = tester.getRect(
            find.widgetWithText(FilledButton, 'Save session'),
          );
          expect(save.left, greaterThanOrEqualTo(20));
          expect(save.right, lessThanOrEqualTo(280));
          expect(save.bottom, lessThanOrEqualTo(580));
          if (session != null) {
            final delete = tester.getRect(
              find.widgetWithText(TextButton, 'Delete'),
            );
            expect(delete.overlaps(save), isFalse);
          }
          expect(tester.takeException(), isNull);
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
