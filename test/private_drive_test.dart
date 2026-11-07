import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/private_windows_token_store.dart';
import 'package:life_manager/data/private_test_environment.dart';
import 'package:life_manager/data/profile_paths.dart';
import 'package:life_manager/data/update_helper_launcher.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';

import 'cloud/google_drive_test.dart' show DriveFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final values = <String, String>{};
  const shared = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    calls.clear();
    values.clear();
    messenger.setMockMethodCallHandler(shared, (_) async {
      fail('Private credentials must never call the shared storage plugin');
    });
    messenger.setMockMethodCallHandler(PrivateWindowsTokenStore.channel, (
      call,
    ) async {
      calls.add(call);
      final args = call.arguments as Map;
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          values[key] = args['value'] as String;
          return null;
        case 'delete':
          values.remove(key);
          return null;
      }
      throw StateError('Unexpected method');
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(shared, null);
    messenger.setMockMethodCallHandler(PrivateWindowsTokenStore.channel, null);
  });
  group(
    'private Windows acceptance configuration',
    skip: !PrivateTestEnvironment.enabled,
    () {
      test(
        'authorization and Standard exchange require explicit scoped approval',
        () {
          final root = PrivateTestEnvironment.validate();
          final authReady = File('${root.path}/AUTHORIZATION-READY');
          if (authReady.existsSync()) authReady.deleteSync();
          expect(
            PrivateTestEnvironment.requireAuthorizationReady,
            throwsStateError,
          );
          authReady.writeAsStringSync('verified-private-profile-v1');
          PrivateTestEnvironment.requireAuthorizationReady();
          expect(PrivateTestEnvironment.syncApproved('synthetic-a'), isFalse);
          final approval = File('${root.path}/STANDARD-SYNC-APPROVED.json');
          approval.writeAsStringSync(
            jsonEncode({
              'account': 'synthetic-a',
              'mode': 'standard',
              'workspaceVerifiedDisposable': true,
            }),
          );
          expect(PrivateTestEnvironment.syncApproved('synthetic-a'), isTrue);
          expect(PrivateTestEnvironment.syncApproved('synthetic-b'), isFalse);
          approval.deleteSync();
        },
      );
      test(
        'fixed profile and every credential purpose avoid shared storage',
        () async {
          final root = PrivateTestEnvironment.validate();
          final profile = ProfilePaths.activeDirectory();
          expect(profile.path, '${root.path}\\Profile');
          for (final purpose in [
            'tokens',
            'sync-workspace-key',
            'sync-reset-operation',
            'oauth-client',
          ]) {
            final store = SecureCloudTokenStore(
              '${profile.path}\\life_manager.sqlite',
              purpose: purpose,
            );
            expect(await store.read(), isNull);
            await store.write('synthetic');
            expect(await store.read(), 'synthetic');
            await store.delete();
            expect(await store.read(), isNull);
          }
          expect(
            calls.every(
              (c) =>
                  (c.arguments as Map)['directory'] ==
                  '${profile.path}\\private-credentials',
            ),
            isTrue,
          );
        },
      );
      test(
        'connect restart refresh and disconnect stay in the chosen store',
        () async {
          final fixture = DriveFixture();
          File('${PrivateTestEnvironment.validate().path}/AUTHORIZATION-READY')
              .writeAsStringSync('verified-private-profile-v1');
          final profile = ProfilePaths.activeDirectory();
          final store = SecureCloudTokenStore(
            '${profile.path}\\life_manager.sqlite',
          );
          GoogleDriveAuth auth() => GoogleDriveAuth(
            client: fixture.client,
            store: store,
            flow: fixture.flow,
            clientId: 'synthetic.apps.googleusercontent.com',
          );
          final first = auth();
          await first.connect();
          expect(values[store.key], isNotNull);
          final restarted = auth();
          await restarted.load();
          await restarted.accessToken(forceRefresh: true);
          expect(fixture.refreshes, 1);
          expect(jsonDecode(values[store.key]!)['accountId'], 'account-a');
          await restarted.disconnect();
          expect(values, isEmpty);
          expect(calls.map((c) => (c.arguments as Map)['key']).toSet(), {
            store.key,
          });
          fixture.client.close();
        },
      );
      test(
        'storage errors propagate without fallback or destructive cleanup',
        () async {
          messenger.setMockMethodCallHandler(PrivateWindowsTokenStore.channel, (
            _,
          ) async {
            throw PlatformException(
              code: 'private_credentials_failed',
              message: 'Retained',
            );
          });
          final store = SecureCloudTokenStore(
            '${ProfilePaths.activeDirectory().path}\\life_manager.sqlite',
          );
          await expectLater(store.read(), throwsA(isA<PlatformException>()));
          await expectLater(
            store.write('synthetic'),
            throwsA(isA<PlatformException>()),
          );
          await expectLater(store.delete(), throwsA(isA<PlatformException>()));
        },
      );
      test(
        'native companion previews launches and update helper are disabled',
        () async {
          var launches = 0;
          final native = NativeWidgetService(
            launcher: (_, _) async {
              launches++;
              return 0;
            },
          );
          expect(native.isAvailable, isFalse);
          await expectLater(native.synchronizeStartup(), throwsStateError);
          await expectLater(native.restoreEnabledWidgets(), throwsStateError);
          await expectLater(native.close(), throwsStateError);
          expect(launches, 0);
          await expectLater(
            startUpdateHelper(
              script: File('unused'),
              arguments: [],
              readyFile: File('unused-ready'),
              resultFile: File('unused-result'),
            ),
            throwsStateError,
          );
          expect(File('unused-ready').existsSync(), isFalse);
        },
      );
    },
  );
}
