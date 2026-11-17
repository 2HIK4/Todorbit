import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/features/mobile/mobile_workspace.dart';
import 'package:life_manager/features/shared_inbox/shared_inbox_screen.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late LifeRepository repo;
  late AppController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('todorbit_nav_test_');
    db = AppDatabase(NativeDatabase.memory());
    repo = LifeRepository(db);
    controller = AppController(repo);
  });

  tearDown(() async {
    await db.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('MobileWorkspace drawer contains Shared Files navigation tile and opens screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefStore = MobilePreferenceStore(
      File('${tempDir.path}/mobile-pref.json'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          home: MobileWorkspace(
            preferenceStore: prefStore,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    final sharedFilesItem = find.text('Shared Files');
    await tester.scrollUntilVisible(
      sharedFilesItem,
      200,
      scrollable: find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(sharedFilesItem, findsOneWidget);

    await tester.tap(sharedFilesItem);
    await tester.pumpAndSettle();

    // Verify SharedInboxScreen is pushed
    expect(find.byType(SharedInboxScreen), findsOneWidget);
    expect(find.text('Shared Files'), findsOneWidget);
    expect(find.text('No shared files yet'), findsOneWidget);
  });
}
