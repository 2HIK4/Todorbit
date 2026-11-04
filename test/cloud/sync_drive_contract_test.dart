import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_manager/app/sync_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/google_drive_provider.dart';
import 'package:life_manager/data/cloud/sync_pairing_service.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/cloud/sync_engine.dart';
import 'package:life_manager/data/cloud/sync_reset_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';

import 'cloud_test_fakes.dart';

// Only HTTP is synthetic: both devices use the production provider, pairing,
// encryption, engine, repository and real persistent SQLite files.
class _DriveWire {
  final files = <String, Map<String, dynamic>>{};
  final payloads = <String, Uint8List>{};
  final sessions = <String, Map<String, dynamic>>{};
  final changes = <String>[];
  int? rejectNext;
  String? rejectReason;
  bool loseUploadReply = false;
  bool failMedia = false;
  bool denyDelete = false;
  bool clientFailure = false;
  int writes = 0;

  http.Response json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  late final client = MockClient((request) async {
    expect(request.url.host, 'www.googleapis.com');
    expect(request.headers['authorization'], 'Bearer synthetic-token');
    if (rejectNext case final status?) {
      rejectNext = null;
      return json({
        'error': {
          'errors': [
            {'reason': rejectReason ?? 'synthetic'},
          ],
        },
      }, status);
    }
    final path = request.url.path;
    if (path.endsWith('/startPageToken')) {
      return json({'startPageToken': '${changes.length}'});
    }
    if (path == '/drive/v3/changes') {
      final offset = int.parse(request.url.queryParameters['pageToken']!);
      return json({
        'newStartPageToken': '${changes.length}',
        'changes': [
          for (final id in changes.skip(offset).toSet())
            {'fileId': id, 'file': files[id]},
        ],
      });
    }
    if (request.method == 'POST' && path == '/upload/drive/v3/files') {
      final id = 'session-${sessions.length}';
      final metadata = jsonDecode(request.body) as Map<String, dynamic>;
      expect(metadata['parents'], ['appDataFolder']);
      expect(metadata['appProperties']['application'], 'todorbit-sync');
      sessions[id] = metadata;
      return http.Response(
        '',
        200,
        headers: {
          'location': 'https://www.googleapis.com/upload/drive/v3/files/$id',
        },
      );
    }
    if (request.method == 'PUT') {
      final metadata = sessions[path.split('/').last]!;
      final bytes = request.bodyBytes;
      expect(
        request.headers['content-range'],
        'bytes 0-${bytes.length - 1}/${bytes.length}',
      );
      final id = 'file-${++writes}';
      payloads[id] = Uint8List.fromList(bytes);
      files[id] = {
        ...metadata,
        'id': id,
        'size': '${bytes.length}',
        'createdTime': DateTime.now().toUtc().toIso8601String(),
        'md5Checksum': md5.convert(bytes).toString(),
        'spaces': ['appDataFolder'],
      };
      changes.add(id);
      if (loseUploadReply) {
        loseUploadReply = false;
        throw const SocketException('Synthetic lost completed-upload reply');
      }
      return json({'id': id});
    }
    if (path == '/drive/v3/files') {
      final query = request.url.queryParameters['q']!;
      expect(query, contains("value='todorbit-sync'"));
      return json({
        'files': [
          for (final file in files.values)
            if (!query.contains("value='workspace'") ||
                file['appProperties']['kind'] == 'workspace' ||
                (query.contains("value='head'") &&
                    file['appProperties']['kind'] == 'head'))
              file,
        ],
      });
    }
    final id = path.split('/').last;
    if (files.containsKey(id)) {
      if (request.method == 'DELETE') {
        if (denyDelete)
          return json({
            'error': {
              'errors': [
                {'reason': 'insufficientPermissions'},
              ],
            },
          }, 403);
        files.remove(id);
        payloads.remove(id);
        return http.Response('', 204);
      }
      if (request.method == 'PATCH') {
        files[id]!['appProperties'] =
            (jsonDecode(request.body) as Map)['appProperties'];
        changes.add(id);
        return json(files[id]!);
      }
      if (request.url.queryParameters['alt'] == 'media') {
        if (failMedia) {
          if (clientFailure) {
            throw http.ClientException('Synthetic interrupted download');
          }
          throw const SocketException('Synthetic interrupted download');
        }
        return http.Response.bytes(payloads[id]!, 200);
      }
      if (request.method == 'GET') return json(files[id]!);
    }
    throw StateError(
      'Unexpected synthetic Drive request: ${request.method} $path',
    );
  });
}

class _Auth extends GoogleDriveAuth {
  _Auth(http.Client client)
    : super(
        client: client,
        store: MemoryTokenStore(),
        flow: TestGoogleFlow(),
        clientId: 'synthetic',
      ) {
    account = const CloudAccount('synthetic-account', 'Disposable contract');
  }
  @override
  Future<void> load() async {}
  @override
  Future<String> accessToken({bool forceRefresh = false}) async =>
      'synthetic-token';
}

class _Device {
  _Device(this.file, this.wire) {
    open();
  }
  final File file;
  final _DriveWire wire;
  final vault = MemoryTokenStore();
  late AppDatabase db;
  late SyncController sync;
  LifeRepository get repo => sync.repository;
  void open() {
    db = AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA journal_mode=WAL');
          db.execute('PRAGMA foreign_keys=ON');
          db.execute('PRAGMA busy_timeout=5000');
        },
      ),
    );
    final auth = _Auth(wire.client);
    final drive = GoogleDriveProvider.sync(auth, wire.client);
    sync = SyncController(
      repository: LifeRepository(db),
      recovery: BackupService(file),
      auth: auth,
      storage: drive,
      pairing: SyncPairingService(storage: drive, vault: vault),
      isUnlocked: () => true,
      onApplied: () async {},
    );
  }

  Future<void> close() async {
    await sync.shutdown();
    sync.dispose();
    await db.close();
  }

  Future<void> restart() async {
    await close();
    open();
  }
}

void main() {
  late Directory root;
  late _DriveWire wire;
  late _Device a, b;
  Future<void> exchange() async {
    await a.sync.syncNow(manual: true);
    await b.sync.syncNow(manual: true);
    await a.sync.syncNow(manual: true);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-wire-contract-');
    wire = _DriveWire();
    a = _Device(File('${root.path}/windows.sqlite'), wire);
    b = _Device(File('${root.path}/android.sqlite'), wire);
    await a.sync.startPrivateSync(
      'wire synthetic memorable passphrase',
      SyncWorkspaceKey.generate(),
    );
    await b.sync.syncNow(manual: true);
    expect(b.sync.needsRecoveryCode, isTrue);
    await b.sync.activate(recoveryCode: await a.sync.recoveryCode());
    await a.sync.setAutomatic(false);
    await b.sync.setAutomatic(false);
  });
  setUpAll(() {
    // Separate file executors intentionally model two isolated devices.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });
  tearDown(() async {
    await a.close();
    await b.close();
    wire.client.close();
    await root.delete(recursive: true);
  });

  for (final reverse in [false, true]) {
    test(
      'production Drive adapter exchanges CRUD in ${reverse ? 'Android to Windows' : 'Windows to Android'} direction',
      () async {
        final sender = reverse ? b : a, receiver = reverse ? a : b;
        final task = await sender.repo.addTask(
          const TaskDraft(title: 'Private synthetic task'),
        );
        final start = DateTime.utc(2026, 11, 5, 10);
        final event = await sender.repo.addEvent(
          EventDraft(
            title: 'Synthetic event',
            startsAt: start,
            endsAt: start.add(const Duration(hours: 1)),
          ),
        );
        await exchange();
        expect((await receiver.repo.tasks()).single.id, task.id);
        expect((await receiver.repo.events()).single.id, event.id);
        await sender.repo.updateTask(
          (await sender.repo.tasks()).single,
          const TaskDraft(title: 'Edited task'),
        );
        await sender.repo.updateEvent(
          (await sender.repo.events()).single,
          EventDraft(
            title: 'Edited event',
            startsAt: start,
            endsAt: start.add(const Duration(hours: 2)),
          ),
        );
        await exchange();
        expect((await receiver.repo.tasks()).single.title, 'Edited task');
        expect((await receiver.repo.events()).single.title, 'Edited event');
        await sender.repo.savePortablePreference('theme', 'dark');
        await exchange();
        expect((await receiver.repo.portablePreferences())['theme'], 'dark');
        await expectLater(
          sender.repo.savePortablePreference('widgetOpacity', 0.5),
          throwsA(isA<FormatException>()),
        );
        await sender.repo.setComplete((await sender.repo.tasks()).single, true);
        await exchange();
        expect(
          (await receiver.repo.tasks()).single.status,
          TaskStatus.completed,
        );
        await sender.repo.deleteTask(task.id);
        await sender.repo.deleteEvent(event.id);
        await exchange();
        for (final device in [a, b]) {
          await device.restart();
          expect(await device.repo.tasks(), isEmpty);
          expect(await device.repo.events(), isEmpty);
          expect(
            (await device.db.customSelect('PRAGMA quick_check').getSingle())
                .data
                .values,
            ['ok'],
          );
          expect(
            await device.db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        }
        expect(
          wire.payloads.values.any(
            (bytes) => utf8
                .decode(bytes, allowMalformed: true)
                .contains('Private synthetic task'),
          ),
          isFalse,
        );
      },
    );
  }

  test('ambiguous upload, failed download and rate limit retain work across restart and retries', () async {
    final task = await a.repo.addTask(const TaskDraft(title: 'Durable retry'));
    wire.loseUploadReply = true;
    await a.sync.syncNow(manual: true);
    expect(a.sync.status.phase, SyncPhase.offline);
    expect((await a.repo.syncExchangeStatus()).pending, greaterThan(0));
    await a.restart();
    await a.sync.syncNow(manual: true);
    wire.failMedia = true;
    await b.sync.syncNow(manual: true);
    expect(await b.repo.tasks(), isEmpty);
    wire.failMedia = false;
    await b.restart();
    wire.rejectNext = 429;
    await b.sync.syncNow(manual: true);
    expect(await b.repo.tasks(), isEmpty);
    await exchange();
    await exchange();
    expect(
      (await b.repo.tasks()).map((t) => t.id),
      [task.id],
      reason:
          'Sender ${a.sync.status.phase}: ${a.sync.status.notice}; receiver '
          '${b.sync.status.phase}: ${b.sync.status.notice}; remote '
          '${wire.files.values.map((f) => f["appProperties"])}',
    );
    expect((await a.repo.syncExchangeStatus()).pending, 0);
    final journal = await b.db
        .customSelect(
          'SELECT operation_id,COUNT(*) AS n FROM sync_journal GROUP BY operation_id HAVING n>1',
        )
        .get();
    expect(journal, isEmpty);
  });

  test('a lost initial proof reply retains the only key and can authorize a second device', () async {
    // A separate empty cloud/profile exercises the first-device creation path.
    await a.close();
    await b.close();
    wire.client.close();
    wire = _DriveWire()..loseUploadReply = true;
    a = _Device(File('${root.path}/first-proof.sqlite'), wire);
    b = _Device(File('${root.path}/second-proof.sqlite'), wire);
    await a.sync.startPrivateSync(
      'wire synthetic memorable passphrase',
      SyncWorkspaceKey.generate(),
    );
    final retained = await a.sync.pairing.saved();
    expect(retained, isNotNull);
    expect(wire.files.values.single['appProperties']['verified'], isNull);
    await a.restart();
    await a.sync.syncNow(manual: true);
    expect(
      (await a.repo.syncExchangeStatus()).binding?.device,
      retained!.binding.device,
    );
    await b.sync.syncNow(manual: true);
    expect(b.sync.needsRecoveryCode, isTrue);
    await b.sync.activate(
      recoveryCode: SyncWorkspaceKey.generate().exportRecoveryCode(),
    );
    expect(await b.sync.pairing.saved(), isNull);
    expect((await b.repo.syncExchangeStatus()).binding, isNull);
    await b.sync.activate(recoveryCode: retained.key.exportRecoveryCode());
    expect(
      (await b.repo.syncExchangeStatus()).binding?.workspace,
      retained.binding.workspace,
    );
    expect(wire.files, hasLength(1));
  });

  test('missing transport marker never permits tampered authenticated ciphertext', () async {
    final task = await a.repo.addTask(
      const TaskDraft(title: 'Authenticated only'),
    );
    wire.loseUploadReply = true;
    await a.sync.syncNow(manual: true);
    final id = wire.files.keys.last;
    final original = wire.payloads[id]!;
    final envelope = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
    final ciphertext = base64Decode(envelope['ciphertext'] as String);
    ciphertext[0] ^= 1;
    envelope['ciphertext'] = base64Encode(ciphertext);
    final damaged = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    wire.payloads[id] = damaged;
    // Even a cloud writer that recomputes the transport hash cannot forge GCM.
    wire.files[id]!['md5Checksum'] = md5.convert(damaged).toString();
    wire.files[id]!['size'] = '${damaged.length}';
    await b.sync.syncNow(manual: true);
    expect(await b.repo.tasks(), isEmpty);
    expect(
      (await b.repo.syncExchangeStatus()).changeToken,
      isNot('${wire.changes.length}'),
    );
    wire.payloads[id] = original;
    wire.files[id]!['md5Checksum'] = md5.convert(original).toString();
    wire.files[id]!['size'] = '${original.length}';
    await exchange();
    expect((await b.repo.tasks()).map((t) => t.id), [task.id]);
  });

  for (final resolveOnFirst in [true, false]) {
    test(
      'Drive adapter bulk decisions on ${resolveOnFirst ? 'Windows' : 'Android'} survive offline restart and genuine new divergence',
      () async {
        for (final title in ['First original', 'Second original']) {
          await a.repo.addTask(TaskDraft(title: title));
        }
        await exchange();
        for (final device in [a, b]) {
          for (final task in await device.repo.tasks()) {
            await device.repo.updateTask(
              task,
              TaskDraft(
                title: '${device == a ? 'Windows' : 'Android'} ${task.id}',
              ),
            );
          }
        }
        await Future.wait([
          a.sync.syncNow(manual: true),
          b.sync.syncNow(manual: true),
        ]);
        await exchange();
        final resolver = resolveOnFirst ? a : b;
        final review = (await resolver.sync.reviewConflicts())!;
        expect(
          review.records.where((r) => r.review.needsDecision),
          hasLength(2),
        );
        wire.failMedia = true;
        wire.clientFailure = !resolveOnFirst;
        final result = await resolver.sync.resolve(review, {
          for (final row in review.records)
            row.id: const SyncResolutionChoice.local(),
        });
        expect(
          result?.state,
          SyncApplyState.applied,
          reason: resolver.sync.message,
        );
        await a.restart();
        await b.restart();
        wire.failMedia = false;
        await exchange();
        await exchange();
        for (final device in [a, b]) {
          expect(await device.sync.reviewConflicts(), isNull);
          expect(
            (await device.repo.tasks()).map((t) => t.title),
            everyElement(startsWith(resolveOnFirst ? 'Windows' : 'Android')),
          );
        }
        final left = (await a.repo.tasks()).first;
        final right = (await b.repo.tasks()).singleWhere(
          (t) => t.id == left.id,
        );
        await a.repo.updateTask(
          left,
          const TaskDraft(title: 'Genuinely new Windows edit'),
        );
        await b.repo.updateTask(
          right,
          const TaskDraft(title: 'Genuinely new Android edit'),
        );
        await exchange();
        expect(
          (await b.sync.reviewConflicts())!.records.any(
            (r) => r.review.needsDecision,
          ),
          isTrue,
        );
      },
    );
  }
  test('production adapter replacement commits head query, validates readback and deletes only retired sync objects; HTTP reasons classify safely', () async {
    final drive = a.sync.pairing.storage;
    for (final fixture in [
      (403, 'storageQuotaExceeded', CloudFailureKind.quota),
      (403, 'insufficientPermissions', CloudFailureKind.permission),
      (401, 'authError', CloudFailureKind.authentication),
      (503, 'backendError', CloudFailureKind.temporary),
    ]) {
      // _send retries one 401, so use the public classifier boundary via 403/503
      // and leave token-refresh behavior to its unchanged auth receipt.
      if (fixture.$1 == 401) continue;
      wire.rejectNext = fixture.$1;
      wire.rejectReason = fixture.$2;
      await expectLater(
        drive.list(),
        throwsA(isA<CloudFailure>().having((e) => e.kind, 'kind', fixture.$3)),
      );
    }
    await a.repo.addTask(const TaskDraft(title: 'Replacement seed'));
    final old = a.sync.snapshot!.binding!;
    final operation = MemoryTokenStore();
    a.sync.reset = SyncResetService(
      repository: a.repo,
      recovery: a.sync.recovery,
      pairing: a.sync.pairing,
      vault: operation,
      isUnlocked: () => true,
    );
    await a.sync.reviewNewSync();
    expect(a.sync.resetState!['phase'], 'review');
    a.sync.needsRecoveryCode = true;
    wire.denyDelete = true;
    await a.sync.startNewSync();
    expect(a.sync.resetState!['phase'], 'cleanup');
    expect(
      a.sync.standardSync,
      isTrue,
      reason: 'New active Standard mode must replace previous Private label even if deletion fails',
    );
    expect(a.sync.needsRecoveryCode, isFalse);
    wire.denyDelete = false;
    await a.sync.resumeNewSync();
    expect(a.sync.resetState!['phase'], 'complete');
    expect(a.sync.problem, isNull);
    final next = (await a.sync.pairing.saved())!;
    await a.sync.pairing.verifyWorkspace(next.binding, next.key);
    expect(
      wire.files.values.any(
        (f) => f['appProperties']['workspaceId'] == old.workspace,
      ),
      isFalse,
    );
    await b.sync.syncNow(manual: true);
    expect(b.sync.problem?.label, 'Reconnect required');
  });
}
