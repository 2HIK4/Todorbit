import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
