import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/platform/android/android_google_drive_auth.dart';
import 'package:life_manager/platform/android/android_platform.dart';

class _IdentityStore implements CloudTokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    value = next;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class _PendingIdentityStore extends _IdentityStore {
  final writing = Completer<void>();
  final continueWrite = Completer<void>();
  bool block = true;
  @override
  Future<void> write(String next) async {
    if (block) {
      block = false;
      writing.complete();
      await continueWrite.future;
    }
    await super.write(next);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidPlatform.channel, null),
  );
  for (final previouslyConnected in [true, false]) {
    test(
      'cancel during secure identity write preserves the previous connection ($previouslyConnected)',
      () async {
        final store = _PendingIdentityStore();
        final previous = previouslyConnected
            ? jsonEncode({
                'version': 1,
                'id': 'first',
                'label': 'original@example.test',
              })
            : null;
        store.value = previous;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              AndroidPlatform.channel,
              (call) async =>
                  call.method == 'googleAuthorize' ? 'pending-token' : null,
            );
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'user': {
                'permissionId': 'first',
                'emailAddress': 'renamed@example.test',
              },
            }),
            200,
          ),
        );
        final auth = AndroidGoogleDriveAuth(client: client, store: store);
        await auth.load();
        final connecting = auth.connect();
        connecting.ignore();
        await store.writing.future;
        auth.flow.cancel();
        store.continueWrite.complete();
        await expectLater(connecting, throwsA(isA<CloudFailure>()));
        expect(store.value, previous);
        expect(
          auth.account?.label,
          previouslyConnected ? 'original@example.test' : null,
        );
        client.close();
      },
    );
  }
  for (final disconnect in [true, false]) {
    test(
      '${disconnect ? 'disconnect' : 'cancel'} invalidates a pending Android account verification',
      () async {
        final store = _IdentityStore();
        final started = Completer<void>();
        final response = Completer<http.Response>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              AndroidPlatform.channel,
              (call) async =>
                  call.method == 'googleAuthorize' ? 'pending-token' : null,
            );
        final client = MockClient((_) {
          started.complete();
          return response.future;
        });
        final auth = AndroidGoogleDriveAuth(client: client, store: store);
        final connecting = auth.connect();
        connecting.ignore();
        await started.future;
        if (disconnect) {
          await auth.disconnect();
        } else {
          auth.flow.cancel();
        }
        response.complete(
          http.Response(
            jsonEncode({
              'user': {
                'permissionId': 'first',
                'emailAddress': 'first@example.test',
              },
            }),
            200,
          ),
        );
        await expectLater(connecting, throwsA(isA<CloudFailure>()));
        expect(store.value, isNull);
        expect(auth.account, isNull);
        client.close();
      },
    );
  }
  test(
    'expired and rejected access tokens are reacquired with the pinned account',
    () async {
      final store = _IdentityStore();
      final requests = <Map<Object?, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidPlatform.channel, (call) async {
            if (call.method != 'googleAuthorize') return null;
            requests.add(call.arguments as Map<Object?, Object?>);
            return 'token-${requests.length}';
          });
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'user': {
              'permissionId': 'first',
              'emailAddress': 'first@example.test',
            },
          }),
          200,
        ),
      );
      final auth = AndroidGoogleDriveAuth(client: client, store: store);
      await auth.connect();
      auth.expires = DateTime.utc(2000);
      expect(await auth.accessToken(), 'token-2');
      expect(requests.last['interactive'], isFalse);
      expect(requests.last['account'], 'first@example.test');
      expect(await auth.accessToken(forceRefresh: true), 'token-3');
      expect(requests.last['force'], isTrue);
      client.close();
    },
  );
  for (final code in ['canceled', 'reconnect', 'services', 'network']) {
    test(
      'Android authorization reports $code without persisting credentials',
      () async {
        final store = _IdentityStore();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              AndroidPlatform.channel,
              (_) async => throw PlatformException(
                code: code,
                message: 'Useful $code message',
              ),
            );
        final client = MockClient(
          (_) async => throw StateError('No identity call expected'),
        );
        final auth = AndroidGoogleDriveAuth(client: client, store: store);
        expect(auth.canConnect, isTrue);
        await expectLater(
          auth.connect(),
          throwsA(
            isA<CloudFailure>().having(
              (e) => e.message,
              'message',
              contains(code),
            ),
          ),
        );
        expect(store.value, isNull);
        expect(auth.account, isNull);
        expect(auth.needsReconnect, code == 'reconnect');
        client.close();
      },
    );
  }
  test(
    'disconnect then reconnect safely switches accounts and retains no tokens',
    () async {
      final store = _IdentityStore();
      var id = 'first';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            AndroidPlatform.channel,
            (call) async => call.method == 'googleAuthorize' ? 'token' : null,
          );
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'user': {'permissionId': id, 'emailAddress': '$id@example.test'},
          }),
          200,
        ),
      );
      final auth = AndroidGoogleDriveAuth(client: client, store: store);
      await auth.connect();
      await auth.disconnect();
      id = 'second';
      await auth.connect();
      expect(auth.account!.id, 'second');
      expect(store.value, isNot(contains('token')));
      client.close();
    },
  );
  test('Android Drive persists identity only and verifies refresh account before using tokens', () async {
    final store = _IdentityStore();
    var account = 'first';
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidPlatform.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'googleAuthorize') return 'short-lived-token';
          return null;
        });
    final client = MockClient((request) async {
      expect(request.url.path, '/drive/v3/about');
      expect(request.headers['Authorization'], 'Bearer short-lived-token');
      return http.Response(
        jsonEncode({
          'user': {
            'permissionId': account,
            'emailAddress': '$account@example.test',
          },
        }),
        200,
      );
    });
    try {
      final auth = AndroidGoogleDriveAuth(
        client: client,
        store: store,
        enabled: true,
      );
      await auth.connect();
      expect(auth.account!.id, 'first');
      final saved = jsonDecode(store.value!) as Map;
      expect(saved.keys.toSet(), {'version', 'id', 'label'});
      expect(store.value, isNot(contains('short-lived-token')));
      final reopened = AndroidGoogleDriveAuth(
        client: client,
        store: store,
        enabled: true,
      );
      await reopened.load();
      expect(reopened.account!.id, 'first');
      expect(await reopened.accessToken(), 'short-lived-token');
      account = 'other';
      await expectLater(
        reopened.accessToken(forceRefresh: true),
        throwsA(isA<CloudFailure>()),
      );
      expect(reopened.needsReconnect, isTrue);
      expect(reopened.account!.id, 'first');
      await reopened.disconnect();
      expect(reopened.account, isNull);
      expect(store.value, isNull);
      expect(calls, contains('googleDisconnect'));
    } finally {
      client.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidPlatform.channel, null);
    }
  });
}
