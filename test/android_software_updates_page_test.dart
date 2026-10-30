import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/software_update_service.dart';
import 'package:life_manager/features/settings/android_software_updates_page.dart';
import 'package:life_manager/platform/android/android_update_service.dart';

class Updates extends AndroidUpdateService {
  AndroidUpdateRelease? result;
  String installation = 'canceled';
  bool permission = false;
  @override
  Future<AndroidUpdateRelease?> check(
    AndroidUpdateDevice device,
    UpdateChannel channel,
  ) async => result;
  @override
  Future<void> clean(Directory directory, {String? keep}) async {}
  @override
  Future<File> download(
    AndroidUpdateRelease release,
    AndroidUpdateDevice device,
    void Function(int, int) progress,
  ) async {
    progress(100, 100);
    return File('test-update.apk');
  }

  @override
  Future<void> verify(AndroidUpdateRelease release, File file) async {}
  @override
  Future<bool> requestInstallPermission() async => permission;
  @override
  Future<String> install(AndroidUpdateRelease release, File file) async =>
      installation;
}

class MemoryStore extends UpdatePreferenceStore {
  MemoryStore() : super(File('unused'));
  UpdatePreferences value = const UpdatePreferences();
  @override
  Future<UpdatePreferences> load() async => value;
  @override
  Future<void> save(UpdatePreferences next) async {
    value = next;
  }
}

void main() {
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'Android update flow, narrow layout and permission denial at $scale text scale',
      (tester) async {
        final root = Directory.systemTemp.createTempSync('android-update-ui-');
        final service = Updates();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(() async {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          root.deleteSync(recursive: true);
        });
        const device = AndroidUpdateDevice(
          versionName: '1.0.18',
          versionCode: 19,
          sdk: 35,
          abis: ['arm64-v8a'],
          distribution: 'github',
          directory: 'unused',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: scale == 1.0 ? Brightness.light : Brightness.dark,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: AndroidSoftwareUpdatesPage(
              service: service,
              store: MemoryStore(),
              loadDevice: () async => device,
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.textContaining('Build number: 19'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Check for Updates'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('Check for Updates'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(
          find.text('No newer compatible Android update is available.'),
          findsOneWidget,
        );
        service.result = AndroidUpdateRelease(
          tag: 'v1.0.19',
          versionName: '1.0.19',
          versionCode: 20,
          publishedAt: DateTime.utc(2026, 10, 29),
          notes: '## Fixed\n- Tasks stay safe',
          uri: Uri.parse('https://github.com'),
          size: 100,
          sha256Digest: 'a' * 64,
        );
        await tester.tap(find.text('Check for Updates'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Download Update'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('Download Update'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Install Update'));
        await tester.tap(find.text('Install Update'));
        // The underlying busy indicator continues while system permission UI
        // is open. Pump the dialog transition without waiting for it to stop.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Allow updates from Todorbit'), findsOneWidget);
        await tester.tap(find.text('Open Android settings'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining('Installation permission was not granted.'),
          -200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.textContaining('Installation permission was not granted.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Play build offers official Play flow without APK install controls',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('android-play-ui-');
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: AndroidSoftwareUpdatesPage(
              service: Updates(),
              store: MemoryStore(),
              loadDevice: () async => const AndroidUpdateDevice(
                versionName: '1.0.18',
                versionCode: 19,
                sdk: 35,
                abis: ['arm64-v8a'],
                distribution: 'play',
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.text('Check Google Play'), findsOneWidget);
        expect(find.text('Install Update'), findsNothing);
        expect(find.text('Check for Updates'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );
}
