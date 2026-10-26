import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/software_update_service.dart';
import 'package:life_manager/features/settings/software_updates_page.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';

class MemoryUpdateStore extends UpdatePreferenceStore {
  MemoryUpdateStore() : super(File('unused-update-test.json'));
  UpdatePreferences value = const UpdatePreferences(automaticChecks: false);

  @override
  Future<UpdatePreferences> load() async => value;

  @override
  Future<void> save(UpdatePreferences next) async => value = next;
}

class FixtureUpdateService extends SoftwareUpdateService {
  @override
  Future<UpdateRelease?> check({
    required String currentVersion,
    required UpdateChannel channel,
    required bool portable,
  }) async => UpdateRelease(
    version: UpdateVersion.parse('1.0.7')!,
    tag: 'v1.0.7',
    notes: '## Verification limits\n\n**Important** release notes &amp; Settings &gt; Backups with a [link](https://example.com).\n\n- One\n- Two',
    assetUri: Uri.parse(
      'https://github.com/2HIK4/Todorbit/releases/download/v1.0.7/Todorbit-1.0.7-win-x64-setup.exe',
    ),
    sha256Digest: 'a' * 64,
    size: 123,
  );
}

void main() {
  testWidgets('Software Updates shows version and saves profile choices', (
    tester,
  ) async {
    final store = MemoryUpdateStore();
    const channel = MethodChannel('life_manager/window_theme');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'getVersion' ? '1.0.5+6' : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SoftwareUpdatesPage(
                nativeWidget: NativeWidgetService(
                  widgetExecutable: 'unavailable.exe',
                ),
                preferenceStore: store,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1.0.5+6'), findsOneWidget);
    expect(find.text('Ready to check'), findsOneWidget);
    expect(find.text('Check for Updates'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump(const Duration(milliseconds: 100));
    expect((await store.load()).automaticChecks, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Update action and collapsed details follow preferences and check',
    (tester) async {
      tester.view.physicalSize = const Size(460, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const channel = MethodChannel('life_manager/window_theme');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => '1.0.6+7');
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = FixtureUpdateService();
      const links = MethodChannel('life_manager/file_dialog');
      String? openedUrl;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(links, (call) async {
            openedUrl = call.arguments as String;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(links, null),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SoftwareUpdatesPage(
                  nativeWidget: NativeWidgetService(
                    widgetExecutable: 'unavailable.exe',
                  ),
                  preferenceStore: MemoryUpdateStore(),
                  updateService: service,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Check for Updates'));
      await tester.pumpAndSettle();
      expect(find.text('Download update'), findsOneWidget);
      expect(find.byType(MarkdownBody), findsNothing);
      expect(find.text('Verification limits'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      final ordered = [
        'Installed version',
        'Status',
        'Available update',
        'Last checked',
        'Automatically check for updates',
        'Update channel',
        'Check for Updates',
        'Download update',
        'Details',
      ];
      for (var index = 1; index < ordered.length; index++) {
        expect(
          tester.getRect(find.text(ordered[index - 1])).top,
          lessThan(tester.getRect(find.text(ordered[index])).top),
          reason: '${ordered[index - 1]} should precede ${ordered[index]}',
        );
      }
      await tester.ensureVisible(find.text('Details'));
      await tester.pumpAndSettle();
      final actionBefore = tester.getRect(find.text('Download update'));
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Verification limits'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              (w.textSpan?.toPlainText() ?? w.data ?? '').contains(
                'Important release notes & Settings > Backups with a link.',
              ),
        ),
        findsOneWidget,
      );
      expect(find.text('Download update'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(tester.getRect(find.text('Download update')), actionBefore);
      final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      markdown.onTapLink!('link', 'https://example.com', '');
      await tester.pump();
      expect(openedUrl, 'https://example.com');
      markdown.onTapLink!('unsafe', 'file:///C:/secret', '');
      await tester.pump();
      expect(openedUrl, 'https://example.com');
      expect(tester.takeException(), isNull);
    },
  );
}
