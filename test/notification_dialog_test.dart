import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/features/settings/notification_dialog.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';

void main() {
  testWidgets('opt-in saves settings and starts the companion', (tester) async {
    if (!Platform.isWindows) return;
    await tester.binding.setSurfaceSize(const Size(850, 680));
    final directory = Directory.systemTemp.createTempSync(
      'life-notification-ui-',
    );
    final widgetFile = File('${directory.path}/life_manager_widget.exe');
    widgetFile.writeAsBytesSync(const []);
    final launched = <List<String>>[];
    final service = NativeWidgetService(
      widgetExecutable: widgetFile.path,
      launcher: (_, args) async {
        launched.add(args);
        return 0;
      },
    );
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    try {
      expect((await repository.notificationSettings()).enabled, isFalse);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => NotificationDialog(service: service),
                  ),
                  child: const Text('Open notifications'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open notifications'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.text('Due task reminders'), findsOneWidget);
      await tester.tap(find.text('Due task reminders'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect((await repository.notificationSettings()).dueReminders, isTrue);
      expect(launched.single.take(2), ['--widget', '--background']);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      directory.deleteSync(recursive: true);
      await tester.binding.setSurfaceSize(null);
    }
  });
}
