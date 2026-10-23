import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
}
