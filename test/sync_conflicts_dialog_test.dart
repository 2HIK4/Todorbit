import 'dart:ui' show ImageByteFormat;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:life_manager/app/sync_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/sync_pairing_service.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/features/settings/sync_encryption_setup_dialog.dart';
import 'package:life_manager/features/settings/sync_reset_dialog.dart';
import 'package:life_manager/data/cloud/sync_problem.dart';
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:life_manager/features/settings/sync_conflicts_dialog.dart';
import 'package:life_manager/features/settings/sync_settings_page.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/shared/sync_status_button.dart';
import 'package:life_manager/data/cloud/sync_engine.dart';
import 'package:life_manager/domain/appearance.dart';

import 'dart:io';

import 'cloud/cloud_test_fakes.dart';
import 'support/mock_sync_drive.dart';

class _Controller extends SyncController {
  _Controller({
    required super.repository,
    required super.recovery,
    required super.auth,
    required super.pairing,
    required bool Function() unlocked,
    required MockSyncDrive drive,
  }) : super(storage: drive, isUnlocked: unlocked, onApplied: () async {});
  SyncProblem? injectedProblem;
  @override
  SyncProblem? get problem => injectedProblem ?? super.problem;
  int applied = 0;
  int requests = 0, privateRequests = 0;
  String? authorizedPassword, generationPassword;
  @override
  Future<void> reconnectGeneration({
    String? password,
    String? recoveryCode,
  }) async {
    generationPassword = password;
  }

  @override
  Future<void> activate({String? recoveryCode, String? password}) async {
    authorizedPassword = password;
  }

  @override
  Future<void> startPrivateSync(String password, SyncWorkspaceKey key) async {
    privateRequests++;
  }

  @override
  Future<void> syncNow({bool manual = false}) async {
    requests++;
  }

  Map<String, SyncResolutionChoice>? selected;
  @override
  Future<SyncApplyResult?> resolve(
    SyncConflictReview review,
    Map<String, SyncResolutionChoice> choices,
  ) async {
    applied++;
    selected = Map.of(choices);
    return const SyncApplyResult(SyncApplyState.applied);
  }

  @override
  Future<void> dismiss(SyncConflictReview review) async {}
}

void main() {
  late AppDatabase database;
  late _Controller controller;
  late Directory root;
  var unlocked = true;
  late MockClient client;
  var providerOwnsController = false;
  final local = {
    'title': 'Study Chapter 2',
    'notes': List.filled(40, 'Long synthetic notes.').join(' '),
  };
  final remote = {
    'title': 'Study Chapter 3',
    'notes': List.filled(40, 'Long synthetic notes.').join(' '),
  };
  final record = SyncConflictRecord(
    entity: 'tasks',
    key: '{"id":"synthetic"}',
    local: local,
    review: SyncRecordReview(
      heads: {'local', 'remote'},
      merged: {'notes': local['notes']},
      conflicts: [
        SyncConflict('title', 'Study Chapter 1', {
          'local': local['title'],
          'remote': remote['title'],
        }),
      ],
    ),
    candidates: {'local': local, 'remote': remote},
    remoteHeads: {'remote'},
  );
  final review = SyncConflictReview(
    token: 'snapshot',
    attentionToken: 'attention',
    records: [record],
    reason: null,
  );
  setUp(() async {
    providerOwnsController = false;
    root = await Directory.systemTemp.createTemp('todorbit-conflict-ui-');
    database = AppDatabase(NativeDatabase.memory());
    final drive = MockSyncDrive(), vault = MemoryTokenStore();
    unlocked = true;
    client = MockClient(
      (_) async => throw StateError('UI fixture must not use network'),
    );
    final auth = GoogleDriveAuth(
      client: client,
      store: MemoryTokenStore(),
      flow: TestGoogleFlow(),
      clientId: 'fixture',
      enabled: false,
    );
    controller = _Controller(
      repository: LifeRepository(database),
      recovery: BackupService(File('${root.path}/unused.sqlite')),
      auth: auth,
      pairing: SyncPairingService(storage: drive, vault: vault),
      unlocked: () => unlocked,
      drive: drive,
    );
  });
  tearDown(() async {
    await controller.shutdown();
    if (!providerOwnsController) controller.dispose();
    client.close();
    await database.close();
    await root.delete(recursive: true);
  });
  Future<void> open(
    WidgetTester tester,
    Size size,
    double scale,
    Brightness brightness,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('audit-capture'),
        child: MaterialApp(
          theme: buildAppTheme(
            brightness,
            brightness == Brightness.dark
                ? ThemePalette.dark
                : ThemePalette.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => SyncConflictsDialog(
                    controller: controller,
                    review: review,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('representative conflict comparison visual evidence', (
    tester,
  ) async {
    final fontPath = Platform.environment['TODORBIT_UI_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('Roboto');
      loader.addFont(
        Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
      );
      await loader.load();
      final iconPath = Platform.environment['TODORBIT_UI_ICONS'];
      if (iconPath != null) {
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          Future.value(ByteData.sublistView(File(iconPath).readAsBytesSync())),
        );
        await icons.load();
      }
    }
    for (final brightness in Brightness.values) {
      for (final compact in [false, true]) {
        await open(
          tester,
          compact ? const Size(390, 844) : const Size(1100, 800),
          1,
          brightness,
        );
        expect(tester.takeException(), isNull);
        final output = Platform.environment['TODORBIT_UI_CAPTURE'];
        if (output != null) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('audit-capture')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(format: ImageByteFormat.png);
            final file = File(
              '$output/conflicts-${brightness.name}-${compact ? 'phone' : 'desktop'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'compact ${brightness.name} large text remains scrollable and bulk choice is not applied immediately',
      (tester) async {
        await open(tester, const Size(360, 640), 2, brightness);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Keep cloud for all (1)'));
        await tester.pumpAndSettle();
        expect(
          find.text('Keep cloud for all (1)').hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text('Keep cloud for all (1)'));
        await tester.pumpAndSettle();
        expect(controller.applied, 0);
        await tester.tap(find.text('Apply selected resolutions'));
        await tester.pumpAndSettle();
        expect(controller.applied, 0);
        expect(find.text('Apply 1 decisions?'), findsOneWidget);
        await tester.tap(find.text('Apply decisions'));
        await tester.pumpAndSettle();
        expect(controller.applied, 1);
        expect(controller.selected![record.id]!.revision, 'remote');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('a locked app closes its conflict route', (tester) async {
    await open(tester, const Size(1100, 800), 1, Brightness.light);
    expect(find.text('Resolve sync conflicts'), findsOneWidget);
    unlocked = false;
    controller.privacyChanged();
    await tester.pumpAndSettle();
    expect(find.text('Resolve sync conflicts'), findsNothing);
    expect(controller.applied, 0);
  });

  testWidgets(
    'recovery input stays visible after keyboard reduces large-text dialog',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      controller.auth.account = const CloudAccount(
        'synthetic',
        'Synthetic device',
      );
      controller.needsRecoveryCode = true;
      providerOwnsController = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            theme: buildAppTheme(
              Brightness.dark,
              ThemePalette.dark,
              android: true,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showSyncSettings(context),
                  child: const Text('Open sync'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sync'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(EditableText).hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.byType(EditableText)).bottom,
        lessThanOrEqualTo(504),
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(controller.shutdown);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('changed values lead and complete records remain available', (
    tester,
  ) async {
    await open(tester, const Size(1100, 800), 1, Brightness.light);
    expect(find.text('Study Chapter 3'), findsOneWidget);
    expect(find.textContaining('Long synthetic notes.'), findsNothing);
    await tester.tap(find.text('Complete record').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Long synthetic notes.'), findsOneWidget);
    expect(controller.applied, 0);
  });

  testWidgets(
    'automatic attention stays a counted badge during sync without opening a route',
    (tester) async {
      providerOwnsController = true;
      controller.engine.status = const SyncEngineStatus(
        SyncPhase.syncing,
        conflicts: 3,
      );
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: Scaffold(body: SyncStatusButton())),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.byTooltip('Sync · Syncing · 3 conflicts need attention'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('3 conflicts need attention')),
        findsOneWidget,
      );
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'the first-device recovery guide does not reopen on every manual sync',
    (tester) async {
      controller.auth.account = const CloudAccount(
        'synthetic',
        'Synthetic account',
      );
      controller.snapshot = const SyncExchangeStatus(
        binding: SyncBinding(
          workspace: 'fixture',
          account: 'synthetic',
          device: 'fixture',
        ),
        enabled: true,
        automatic: true,
        quarantined: false,
        pending: 0,
        conflicts: 0,
        waiting: 0,
      );
      controller.engine.status = const SyncEngineStatus(SyncPhase.upToDate);
      controller.recoveryReminder = true;
      providerOwnsController = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: Scaffold(body: SyncStatusButton())),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('sync-status-button')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Save your recovery code'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(controller.recoveryReminder, isFalse);
      await tester.tap(find.byKey(const ValueKey('sync-status-button')));
      await tester.pumpAndSettle();
      expect(controller.requests, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final brightness in Brightness.values) {
    for (final state in [
      'disconnected',
      'ready',
      'recovery',
      'synced',
      'offline',
      'conflicts',
    ]) {
      testWidgets(
        'compact ${brightness.name} Sync $state at 200 percent text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(360, 640);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          if (state != 'disconnected') {
            controller.auth.account = const CloudAccount(
              'synthetic',
              'very.long.synthetic.google.account.address.for.layout@example.invalid',
            );
          }
          controller.needsRecoveryCode = state == 'recovery';
          if (['synced', 'offline', 'conflicts'].contains(state)) {
            controller.snapshot = SyncExchangeStatus(
              binding: const SyncBinding(
                workspace: 'fixture',
                account: 'synthetic',
                device: 'fixture',
              ),
              enabled: true,
              automatic: true,
              quarantined: false,
              pending: 0,
              conflicts: state == 'conflicts' ? 3 : 0,
              waiting: 0,
            );
            controller.engine.status = SyncEngineStatus(
              state == 'synced'
                  ? SyncPhase.upToDate
                  : state == 'offline'
                  ? SyncPhase.offline
                  : SyncPhase.needsAttention,
              conflicts: state == 'conflicts' ? 3 : 0,
              lastSuccess: DateTime.utc(2026, 11, 3, 10),
            );
          }
          providerOwnsController = true;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                syncControllerProvider.overrideWith((ref) => controller),
              ],
              child: RepaintBoundary(
                key: const ValueKey('sync-capture'),
                child: MaterialApp(
                  theme: buildAppTheme(
                    brightness,
                    brightness == Brightness.dark
                        ? ThemePalette.dark
                        : ThemePalette.light,
                    android: true,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showSyncSettings(context),
                        child: const Text('Open sync'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open sync'));
          await tester.pumpAndSettle();
          expect(
            find.byType(TextField),
            state == 'recovery' ? findsOneWidget : findsNothing,
          );
          expect(find.text('Pair your devices'), findsNothing);
          final primary = find.byType(FilledButton);
          await tester.ensureVisible(primary);
          await tester.pumpAndSettle();
          expect(primary.hitTestable(), findsOneWidget);
          expect(find.text('Close').hitTestable(), findsOneWidget);
          if (state == 'conflicts') {
            await tester.ensureVisible(find.text('Review conflicts'));
            await tester.pumpAndSettle();
            expect(find.text('Review conflicts').hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          final output = Platform.environment['TODORBIT_UI_CAPTURE'];
          if (output != null) {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('sync-capture')),
              );
              final image = await boundary.toImage();
              final bytes = await image.toByteData(format: ImageByteFormat.png);
              final file = File(
                '$output/sync-${brightness.name}-$state-2x.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'short landscape conflict confirmation remains reachable at 200 percent text',
    (tester) async {
      await open(tester, const Size(640, 360), 2, Brightness.dark);
      await tester.ensureVisible(find.text('Keep cloud for all (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep cloud for all (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply selected resolutions'));
      await tester.pumpAndSettle();
      expect(find.text('Apply decisions').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(controller.applied, 0);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'private encryption setup ${brightness.name} validates and fits large text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showPrivateSyncSetup(context, controller),
                  child: const Text('Open encryption'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open encryption'));
        await tester.pumpAndSettle();
        expect(find.text('Private Encrypted Sync'), findsOneWidget);
        await tester.ensureVisible(find.text('I saved my recovery code'));
        await tester.tap(find.text('I saved my recovery code'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Connect with encryption'));
        await tester.pumpAndSettle();
        expect(controller.privateRequests, 0);
        expect(
          find.textContaining('Use at least 12 characters'),
          findsOneWidget,
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'quiet orchard violet bicycle');
        await tester.enterText(fields.at(1), 'a different memorable phrase');
        await tester.tap(find.text('Connect with encryption'));
        await tester.pumpAndSettle();
        expect(find.text('The passphrases do not match.'), findsOneWidget);
        await tester.enterText(fields.at(1), 'quiet orchard violet bicycle');
        await tester.tap(find.text('Connect with encryption'));
        await tester.pumpAndSettle();
        expect(controller.privateRequests, 1);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'private setup privacy closure preserves its parent on repeated lock notifications',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (parentContext) => AlertDialog(
                    title: const Text('Sync parent'),
                    content: TextButton(
                      onPressed: () =>
                          showPrivateSyncSetup(parentContext, controller),
                      child: const Text('Private setup'),
                    ),
                  ),
                ),
                child: const Text('Open parent'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private setup'));
      await tester.pumpAndSettle();
      unlocked = false;
      controller.privacyChanged();
      controller.privacyChanged();
      await tester.pumpAndSettle();
      expect(find.text('Private Encrypted Sync'), findsNothing);
      expect(find.text('Sync parent'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('private passphrase input preserves intentional spaces', (
    tester,
  ) async {
    controller.auth.account = const CloudAccount(
      'mock-only',
      'Synthetic account',
    );
    controller.needsRecoveryCode = true;
    controller.pairing.passwordAvailable = true;
    providerOwnsController = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSyncSettings(context),
                child: const Text('Open Sync'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use recovery code'));
    await tester.pumpAndSettle();
    const passphrase = '  quiet orchard violet bicycle  ';
    await tester.enterText(find.byType(TextField), passphrase);
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Authorize this device'),
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Authorize this device'),
    );
    await tester.pumpAndSettle();
    expect(controller.authorizedPassword, passphrase);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'new sync confirmation wraps at 200 percent in both themes and requires explicit acknowledgment',
    (tester) async {
      final loader = FontLoader('Roboto');
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
          ),
        ),
      );
      await loader.load();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(380, 780);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      controller.auth.account = const CloudAccount(
        'mock-only',
        'Synthetic selected account',
      );
      controller.resetState = {
        'phase': 'review',
        'selected': ['f5b38e9c-f962-441e-a0fc-c057de8e1f88'],
        'backup': 'Synthetic isolated recovery snapshot',
      };
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('reset-capture'),
            child: MaterialApp(
              theme: buildAppTheme(
                brightness,
                brightness == Brightness.dark
                    ? ThemePalette.dark
                    : ThemePalette.light,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) =>
                          SyncResetConfirmation(controller: controller),
                    ),
                    child: const Text('Open reset'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open reset'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start New Sync'),
              )
              .onPressed,
          isNull,
        );
        expect(find.textContaining('Cloud-only records'), findsOneWidget);
        final capture = Platform.environment['TODORBIT_RESET_CAPTURE'];
        if (capture != null) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('reset-capture')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(format: ImageByteFormat.png);
            await File('$capture-${brightness.name}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start New Sync'),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'specific sync errors expose correct recovery action and status opens details without retrying',
    (tester) async {
      controller.auth.account = const CloudAccount(
        'mock-only',
        'Synthetic account',
      );
      controller.injectedProblem = SyncProblem.from(
        const CloudFailure(
          'PRIVATE SERVER TEXT',
          kind: CloudFailureKind.offline,
        ),
      );
      providerOwnsController = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(home: Scaffold(body: const SyncStatusButton())),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('sync-status-button')));
      await tester.pumpAndSettle();
      expect(controller.requests, 0);
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.textContaining('PRIVATE SERVER TEXT'), findsNothing);
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Retry sync'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry sync'));
      await tester.pumpAndSettle();
      expect(controller.requests, 1);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      controller.injectedProblem = SyncProblem.from(
        const CloudFailure('', kind: CloudFailureKind.credentials),
      );
      controller.reconnectingGeneration = true;
      controller.needsRecoveryCode = true;
      controller.pairing.passwordAvailable = true;
      await tester.tap(find.byKey(const ValueKey('sync-status-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use recovery code'));
      await tester.tap(find.text('Use recovery code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'new generation private phrase',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Authorize this device'),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Authorize this device'),
      );
      await tester.pumpAndSettle();
      expect(controller.generationPassword, 'new generation private phrase');
      expect(controller.authorizedPassword, isNull);

      expect(tester.takeException(), isNull);
    },
  );
}
