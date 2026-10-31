import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/google_drive_provider.dart';
import 'package:test/test.dart';

import 'cloud_test_fakes.dart';

class _Auth extends GoogleDriveAuth {
  _Auth(http.Client client)
    : super(
        client: client,
        store: MemoryTokenStore(),
        flow: TestGoogleFlow(),
        clientId: 'fixture',
      ) {
    account = const CloudAccount('account', 'Disposable');
  }
  Future<void> Function()? beforeToken;
  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    await beforeToken?.call();
    return 'fixture-token';
  }
}

http.Response response(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
Map<String, Object?> file(String id, {String namespace = 'todorbit-sync'}) => {
  'id': id,
  'name': 'opaque.tdsync',
  'size': '100',
  'createdTime': '2026-10-31T00:00:00Z',
  'md5Checksum': 'fixture',
  'spaces': ['appDataFolder'],
  'appProperties': {'application': namespace, 'batchId': id},
};

void main() {
  test(
    'sync namespace and change checkpoints remain independent from backups',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer fixture-token');
        if (request.url.path.endsWith('startPageToken')) {
          return response({'startPageToken': 'before-list'});
        }
        expect(
          request.url.queryParameters['q'],
          contains("value='todorbit-sync'"),
        );
        return response({
          'files': [file('batch')],
        });
      });
      addTearDown(client.close);
      final drive = GoogleDriveProvider.sync(_Auth(client), client);
      expect(await drive.startChangeToken(), 'before-list');
      expect((await drive.list()).single.id, 'batch');
    },
  );

  test('paged changes retain removal signals without turning them into row deletion', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['spaces'], 'appDataFolder');
      final first = request.url.queryParameters['pageToken'] == 'start';
      return response({
        if (first)
          'nextPageToken': 'page-two'
        else
          'newStartPageToken': 'complete',
        'changes': first
            ? [
                {'fileId': 'sync', 'removed': false, 'file': file('sync')},
                {
                  'fileId': 'backup',
                  'removed': false,
                  'file': file('backup', namespace: 'todorbit'),
                },
                {'fileId': 'lost-history', 'removed': true},
              ]
            : [],
      });
    });
    addTearDown(client.close);
    final drive = GoogleDriveProvider.sync(_Auth(client), client);
    final page = await drive.changes('start');
    expect(page.objects.single.id, 'sync');
    expect(page.removedIds, {'lost-history'});
    expect(page.hasMore, isTrue);
    expect(page.checkpoint, 'page-two');
    final finalPage = await drive.changes(page.checkpoint);
    expect(finalPage.hasMore, isFalse);
    expect(finalPage.checkpoint, 'complete');
  });

  test(
    'expired, repeated and mismatched change pages do not advance state',
    () async {
      for (final body in [
        {'nextPageToken': 'start', 'changes': []},
        {
          'newStartPageToken': 'end',
          'changes': [
            {'fileId': 'wrong', 'file': file('actual')},
          ],
        },
        {'newStartPageToken': 'end', 'nextPageToken': 'other', 'changes': []},
      ]) {
        final client = MockClient((_) async => response(body));
        final drive = GoogleDriveProvider.sync(_Auth(client), client);
        await expectLater(drive.changes('start'), throwsA(isA<CloudFailure>()));
        client.close();
      }
      final client = MockClient((_) async => response({}, 410));
      addTearDown(client.close);
      await expectLater(
        GoogleDriveProvider.sync(_Auth(client), client).changes('expired'),
        throwsA(isA<DriveCheckpointExpired>()),
      );
    },
  );

  test(
    'account switch while obtaining a token never sends to another account',
    () async {
      var sends = 0;
      final client = MockClient((_) async {
        sends++;
        return response({'startPageToken': 'token'});
      });
      addTearDown(client.close);
      final auth = _Auth(client);
      auth.beforeToken = () async {
        auth.account = const CloudAccount('other', 'Other');
      };
      await expectLater(
        GoogleDriveProvider.sync(auth, client).startChangeToken(),
        throwsA(isA<CloudFailure>()),
      );
      expect(sends, 0);
    },
  );
}
