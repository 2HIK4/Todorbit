import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/google_drive_provider.dart';

import 'cloud_test_fakes.dart';

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

class DriveFixture {
  final store = MemoryTokenStore();
  final configurationStore = MemoryTokenStore();
  final flow = TestGoogleFlow();
  String identity = 'account-a';
  int refreshes = 0, mediaReads = 0, uploadStatus = 200;
  bool revoked = false, corruptDownload = false, offline = false;
  bool interruptUpload = false,
      truncateDownload = false,
      unauthorizedOnce = false;
  bool paginate = false;
  String? expectedClientSecret;
  final uploaded = BytesBuilder();
  Uint8List? stored;
  Map<String, String> properties = {};
  late final http.Client client = MockClient((request) async {
    if (offline) throw const SocketException('offline');
    if (request.url.host == 'oauth2.googleapis.com') {
      final fields = Uri.splitQueryString(request.body);
      expect(fields['client_secret'], expectedClientSecret);
      if (fields['grant_type'] == 'refresh_token') {
        refreshes++;
        if (revoked) return jsonResponse({'error': 'invalid_grant'}, 400);
      } else {
        final verifier = fields['code_verifier']!;
        expect(verifier.length, greaterThanOrEqualTo(43));
        expect(
          flow.authorization!.queryParameters['code_challenge'],
          base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes)
              .replaceAll('=', ''),
        );
      }
      return jsonResponse({
        'access_token': 'access-$refreshes',
        'token_type': 'Bearer',
        'refresh_token': 'refresh',
        'expires_in': 3600,
        'scope': GoogleDriveAuth.scope,
      });
    }
    if (request.url.path.endsWith('/about')) {
      return jsonResponse({
        'user': {
          'permissionId': identity,
          'emailAddress': '$identity@example.test',
        },
      });
    }
    if (request.method == 'POST' && request.url.path.startsWith('/upload/')) {
      uploaded.clear();
      if (uploadStatus != 200) return jsonResponse({}, uploadStatus);
      final data = jsonDecode(request.body) as Map;
      expect(data['parents'], ['appDataFolder']);
      properties = (data['appProperties'] as Map).cast<String, String>();
      return http.Response(
        '',
        200,
        headers: {
          'location':
              'https://www.googleapis.com/upload/drive/v3/files?upload_id=test',
        },
      );
    }
    if (request.method == 'PUT') {
      if (interruptUpload && uploaded.isNotEmpty) {
        throw const SocketException('interrupted upload');
      }
      uploaded.add(request.bodyBytes);
      final range = request.headers['content-range']!;
      final total = int.parse(range.split('/').last);
      if (uploaded.length < total) {
        return http.Response(
          '',
          308,
          headers: {'range': 'bytes=0-${uploaded.length - 1}'},
        );
      }
      stored = uploaded.takeBytes();
      return jsonResponse({'id': 'file-a'});
    }
    if (request.url.queryParameters['alt'] == 'media') {
      mediaReads++;
      final bytes = Uint8List.fromList(stored!);
      if (corruptDownload) bytes[0] ^= 1;
      if (truncateDownload) return http.Response.bytes(bytes.sublist(1), 200);
      return http.Response.bytes(bytes, 200);
    }
    if (request.method == 'DELETE') return http.Response('', 204);
    if (request.method == 'PATCH') {
      properties = ((jsonDecode(request.body) as Map)['appProperties'] as Map)
          .cast<String, String>();
      return jsonResponse(metadata);
    }
    if (request.url.path.endsWith('/files')) {
      if (unauthorizedOnce) {
        unauthorizedOnce = false;
        return http.Response('', 401);
      }
      expect(request.url.queryParameters['spaces'], 'appDataFolder');
      final second = request.url.queryParameters['pageToken'] != null;
      return jsonResponse({
        'files': stored == null
            ? []
            : [
                {...metadata, if (second) 'id': 'file-b'},
              ],
        if (paginate && !second) 'nextPageToken': 'second-page',
      });
    }
    return jsonResponse(metadata);
  });
  Map<String, dynamic> get metadata => {
    'id': 'file-a',
    'name': 'backup.tdbackup',
    'size': '${stored!.length}',
    'createdTime': '2026-10-25T09:00:00Z',
    'md5Checksum': md5.convert(stored!).toString(),
    'appProperties': properties,
    'spaces': ['appDataFolder'],
  };
  late final auth = GoogleDriveAuth(
    client: client,
    store: store,
    configurationStore: configurationStore,
    flow: flow,
    clientId: 'test.apps.googleusercontent.com',
  );
  late final provider = GoogleDriveProvider(auth, client);
}

void main() {
  test('bundled public Desktop parameters connect and refresh after restart without a configuration import', () async {
    final fixture = DriveFixture();
    fixture.expectedClientSecret = 'public-desktop-parameter';
    GoogleDriveAuth publicAuth() => GoogleDriveAuth(
      client: fixture.client,
      store: fixture.store,
      flow: fixture.flow,
      clientId: fixture.auth.clientId,
      clientSecret: fixture.expectedClientSecret!,
    );
    final auth = publicAuth();
    await auth.load();
    expect(auth.configurationStore, isNull);
    expect(auth.canConnect, isTrue);
    await auth.connect();
    expect(fixture.configurationStore.value, isNull);
    expect(fixture.store.value, isNot(contains(fixture.expectedClientSecret!)));
    final restarted = publicAuth();
    await restarted.load();
    expect(restarted.account!.id, 'account-a');
    await restarted.accessToken(forceRefresh: true);
    expect(fixture.refreshes, 1);
    await restarted.disconnect();
    expect(fixture.store.value, isNull);
    await restarted.connect();
    expect(restarted.account!.id, 'account-a');
  });

  test(
    'disabled public access never loads saved tokens or opens the browser',
    () async {
      final fixture = DriveFixture();
      await fixture.auth.connect();
      final saved = fixture.store.value;
      final flow = TestGoogleFlow();
      final auth = GoogleDriveAuth(
        client: fixture.client,
        store: fixture.store,
        flow: flow,
        clientId: fixture.auth.clientId,
        clientSecret: 'public-desktop-parameter',
        enabled: false,
      );
      await auth.load();
      expect(auth.account, isNull);
      expect(auth.canConnect, isFalse);
      await expectLater(auth.connect(), throwsA(isA<CloudFailure>()));
      await expectLater(auth.accessToken(), throwsA(isA<CloudFailure>()));
      expect(flow.authorization, isNull);
      expect(fixture.store.value, saved);
    },
  );

  test('Desktop configuration stays in secure storage, is allowlisted, survives restart and supports client authentication', () async {
    final fixture = DriveFixture();
    fixture.expectedClientSecret = 'fixture-only-client-secret';
    final credentials = jsonEncode({
      'installed': {
        'client_id': fixture.auth.clientId,
        'client_secret': fixture.expectedClientSecret,
        'auth_uri': 'https://untrusted.invalid',
        'refresh_token': 'must-not-import',
      },
    });
    await fixture.auth.importClientConfiguration(credentials);
    expect(
      fixture.configurationStore.value,
      isNot(contains('untrusted.invalid')),
    );
    expect(
      fixture.configurationStore.value,
      isNot(contains('must-not-import')),
    );
    expect(fixture.store.value, isNull);
    await fixture.auth.connect();
    expect(fixture.store.value, isNot(contains(fixture.expectedClientSecret!)));
    await fixture.auth.accessToken(forceRefresh: true);
    await expectLater(
      fixture.auth.removeClientConfiguration(),
      throwsA(isA<CloudFailure>()),
    );
    await fixture.auth.disconnect();
    expect(fixture.store.value, isNull);
    expect(fixture.configurationStore.value, isNotNull);
    final restarted = GoogleDriveAuth(
      client: fixture.client,
      store: fixture.store,
      configurationStore: fixture.configurationStore,
      flow: fixture.flow,
      clientId: fixture.auth.clientId,
    );
    await restarted.load();
    expect(restarted.hasClientConfiguration, isTrue);
    await restarted.connect();
    await restarted.disconnect();
    await expectLater(
      restarted.importClientConfiguration(
        jsonEncode({
          'web': {'client_id': fixture.auth.clientId},
        }),
      ),
      throwsA(isA<CloudFailure>()),
    );
    await expectLater(
      restarted.importClientConfiguration(
        jsonEncode({
          'installed': {'client_id': 'other.apps.googleusercontent.com'},
        }),
      ),
      throwsA(isA<CloudFailure>()),
    );
    await restarted.removeClientConfiguration();
    expect(fixture.configurationStore.value, isNull);
    expect(restarted.hasClientConfiguration, isFalse);
  });
  test('expired tokens and a 401 refresh, paginated listing, and interrupted transfers preserve snapshots', () async {
    final fixture = DriveFixture();
    await fixture.auth.connect();
    final old = jsonDecode(fixture.store.value!) as Map<String, dynamic>;
    old['expiresAt'] = 0;
    fixture.store.value = jsonEncode(old);
    await fixture.auth.load();
    await fixture.auth.accessToken();
    expect(fixture.refreshes, 1);
    final previous = await fixture.provider.upload(
      Uint8List.fromList([1, 2, 3]),
      {'backupId': 'old', 'kind': 'full'},
      (_, _, _) {},
    );
    fixture.paginate = true;
    fixture.unauthorizedOnce = true;
    expect((await fixture.provider.list()).map((o) => o.id), [
      'file-a',
      'file-b',
    ]);
    expect(fixture.refreshes, 2);
    fixture.interruptUpload = true;
    await expectLater(
      fixture.provider.upload(Uint8List(1024 * 1024 + 20), {
        'backupId': 'new',
      }, (_, _, _) {}),
      throwsA(isA<SocketException>()),
    );
    expect(fixture.stored, [1, 2, 3]);
    fixture.truncateDownload = true;
    // Restore prior metadata because this fixture represents a newly allocated
    // upload session separately from the existing remote file.
    fixture.properties = previous.properties;
    await expectLater(
      fixture.provider.download(previous, (_, _, _) {}),
      throwsA(isA<CloudFailure>()),
    );
  });
  test('PKCE requests only appdata, saves secure session, loads, refreshes, and disconnects offline', () async {
    final fixture = DriveFixture();
    await fixture.auth.connect();
    final query = fixture.flow.authorization!.queryParameters;
    expect(query['scope'], GoogleDriveAuth.scope);
    expect(query['prompt'], contains('select_account'));
    expect(fixture.store.value, contains('refresh_token'));
    final restarted = GoogleDriveAuth(
      client: fixture.client,
      store: fixture.store,
      flow: TestGoogleFlow(),
      clientId: fixture.auth.clientId,
    );
    await restarted.load();
    expect(restarted.account!.id, 'account-a');
    await restarted.accessToken(forceRefresh: true);
    expect(fixture.refreshes, 1);
    fixture.offline = true;
    await restarted.disconnect();
    expect(restarted.account, isNull);
    expect(fixture.store.value, isNull);
  });

  test('canceled sign-in and invalid state never save a session', () async {
    final fixture = DriveFixture();
    fixture.flow.canceled = true;
    await expectLater(fixture.auth.connect(), throwsA(isA<CloudFailure>()));
    fixture.flow.canceled = false;
    fixture.flow.wrongState = true;
    await expectLater(fixture.auth.connect(), throwsA(isA<CloudFailure>()));
    expect(fixture.store.value, isNull);
  });

  test('account switching is rejected until disconnect, stale objects are rejected', () async {
    final fixture = DriveFixture();
    await fixture.auth.connect();
    final oldSession = fixture.store.value;
    fixture.identity = 'account-b';
    await expectLater(fixture.auth.connect(), throwsA(isA<CloudFailure>()));
    expect(fixture.store.value, oldSession);
    await expectLater(
      fixture.auth.accessToken(forceRefresh: true),
      throwsA(isA<CloudFailure>()),
    );
    final oldObject = CloudObject(
      id: 'old',
      accountId: 'account-a',
      name: 'old',
      bytes: 10,
      createdAt: DateTime.utc(2026),
      properties: {},
      md5: 'x',
    );
    await fixture.auth.disconnect();
    await fixture.auth.connect();
    await expectLater(
      fixture.provider.delete(oldObject),
      throwsA(isA<CloudFailure>()),
    );
    expect(fixture.auth.account!.id, 'account-b');
  });

  test(
    'revoked refresh requires reconnect without exposing provider error',
    () async {
      final fixture = DriveFixture();
      await fixture.auth.connect();
      fixture.revoked = true;
      await expectLater(
        fixture.auth.accessToken(forceRefresh: true),
        throwsA(isA<CloudFailure>()),
      );
      expect(fixture.auth.needsReconnect, isTrue);
    },
  );

  test(
    'upload chunks, remote readback, list, download and delete are confirmed',
    () async {
      final fixture = DriveFixture();
      await fixture.auth.connect();
      final bytes = Uint8List.fromList(
        List.generate(1024 * 1024 + 50, (i) => i % 256),
      );
      final progress = <String>[];
      final object = await fixture.provider.upload(bytes, {
        'backupId': 'id',
        'kind': 'full',
        'formatVersion': '1',
      }, (stage, done, total) => progress.add('$stage:$done'));
      expect(object.bytes, bytes.length);
      expect(fixture.mediaReads, 1);
      expect(progress.any((s) => s.endsWith(':1048576')), isTrue);
      expect(await fixture.provider.list(), hasLength(1));
      expect(await fixture.provider.download(object, (_, _, _) {}), bytes);
      await fixture.provider.delete(object);
    },
  );

  test(
    'quota, corrupted readback and offline errors never report upload success',
    () async {
      final fixture = DriveFixture();
      await fixture.auth.connect();
      fixture.uploadStatus = 403;
      await expectLater(
        fixture.provider.upload(Uint8List.fromList([1, 2]), {
          'backupId': 'id',
        }, (_, _, _) {}),
        throwsA(isA<CloudFailure>()),
      );
      fixture.uploadStatus = 200;
      fixture.corruptDownload = true;
      await expectLater(
        fixture.provider.upload(Uint8List.fromList([1, 2]), {
          'backupId': 'id',
        }, (_, _, _) {}),
        throwsA(isA<CloudFailure>()),
      );
      fixture.offline = true;
      await expectLater(
        fixture.provider.list(),
        throwsA(isA<SocketException>()),
      );
    },
  );

  test(
    'loopback ignores invalid state, then accepts valid callback and closes',
    () async {
      late Uri callback;
      final client = http.Client();
      final flow = LoopbackGoogleAuthorization(
        openBrowser: (uri) async {
          callback = Uri.parse(uri.queryParameters['redirect_uri']!);
          final invalid = await client.get(
            callback.replace(
              queryParameters: {'code': 'attack', 'state': 'wrong'},
            ),
          );
          expect(invalid.statusCode, 400);
          final valid = await client.get(
            callback.replace(
              queryParameters: {'code': 'good', 'state': 'expected'},
            ),
          );
          expect(valid.statusCode, 200);
          return true;
        },
      );
      try {
        final result = await flow.authorize(
          (redirect) => Uri.https('accounts.google.com', '/auth', {
            'redirect_uri': redirect,
            'state': 'expected',
          }),
        );
        expect(result['code'], 'good');
        await expectLater(
          client.get(callback),
          throwsA(isA<http.ClientException>()),
        );
      } finally {
        client.close();
      }
    },
  );

  test('loopback cancellation closes the listener', () async {
    late LoopbackGoogleAuthorization flow;
    flow = LoopbackGoogleAuthorization(
      openBrowser: (_) async {
        flow.cancel();
        return true;
      },
    );
    await expectLater(
      flow.authorize(
        (redirect) => Uri.https('accounts.google.com', '/auth', {
          'redirect_uri': redirect,
          'state': 'expected',
        }),
      ),
      throwsA(isA<CloudFailure>()),
    );
  });
}
