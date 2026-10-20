import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/app/privacy_manager.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/data/privacy_store.dart';
import 'package:life_manager/features/settings/privacy_dialog.dart';
import 'package:life_manager/main.dart';

void main() {
  late Directory directory;
  late PrivacyStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'life-manager-privacy-test-',
    );
    store = PrivacyStore(File('${directory.path}/privacy-settings.json'));
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('setup, locked restart, PIN change and removal persist', () async {
    final initial = await store.load();
    expect(initial.enabled, isFalse);
    final manager = PrivacyManager(store, initial);
    await manager.setup('123456');
    expect((await store.load()).enabled, isTrue);
    expect(await store.file.readAsString(), isNot(contains('123456')));
    await manager.lock();
    expect(manager.locked, isTrue);
    expect(await manager.unlock('000000'), isFalse);
    expect(await manager.unlock('123456'), isTrue);
    expect(await manager.changePin('123456', '654321'), isTrue);
    expect(await manager.verify('123456'), isFalse);
    expect(await manager.verify('654321'), isTrue);
    await manager.lock();
    final restarted = PrivacyManager(store, await store.load());
    expect(restarted.locked, isTrue);
    expect(await restarted.unlock('654321'), isTrue);
    expect(await restarted.remove('654321'), isTrue);
    expect((await store.load()).enabled, isFalse);
    await restarted.shutdown();
    await manager.shutdown();
    restarted.dispose();
    manager.dispose();
  });

  test('failed-attempt delay survives restart', () async {
    final manager = PrivacyManager(store, const PrivacySettings());
    await manager.setup('123456');
    for (var index = 0; index < 5; index++) {
      expect(await manager.verify('000000'), isFalse);
    }
    expect(manager.retryDelay, isNotNull);
    final restarted = PrivacyManager(store, await store.load());
    expect(await restarted.verify('123456'), isFalse);
    expect(restarted.retryDelay, isNotNull);
    await restarted.shutdown();
    await manager.shutdown();
    restarted.dispose();
    manager.dispose();
  });

  test('lifecycle interruption relocks when opted in', () async {
    final manager = PrivacyManager(store, const PrivacySettings());
    try {
      await manager.setup('123456');
      await manager.updateSettings(
        manager.settings.copyWith(lockOnInactive: true),
      );
      manager.becameInactive();
      await manager.resumed();
      expect(manager.locked, isTrue);
    } finally {
      await manager.shutdown();
      manager.dispose();
    }
  });

  test('corrupt policy fails closed', () async {
    await store.file.writeAsString('{bad json');
    expect(store.load(), throwsStateError);
  });

  test('PIN verifier matches the PBKDF2-HMAC-SHA256 reference vector', () {
    expect(
      PrivacyStore.derivePin('123456', 'AAECAwQFBgcICQoLDA0ODw==', 210000),
      '986qxnMbMmzuHyS3MK9F7gz4EXIuhMjAubUlwLFpHTo=',
    );
  });

  testWidgets('locked shell never builds task workspace', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    final manager = PrivacyManager(store, const PrivacySettings(enabled: true));
    try {
      await repository.addTask(
        TaskDraft(
          title: 'Private task title',
          scheduledDate: localDate(DateTime.now()),
        ),
      );
      await controller.initialize();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyManagerProvider.overrideWith((ref) => manager),
          ],
          child: const LifeManagerApp(),
        ),
      );
      await tester.pump();
      expect(find.text('Private task title'), findsNothing);
      expect(find.text('Todorbit is locked'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await database.close();
    }
  });
}
