import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/widget_configuration_store.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/features/settings/widget_settings_page.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';

class MemoryWidgetConfigurations extends WidgetConfigurationStore {
  MemoryWidgetConfigurations() : super(Directory('unused'));
  final values = {
    DesktopWidgetKind.tasks: WidgetConfiguration(
      enabled: true,
      navigationPosition: WidgetNavigationPosition.right,
    ),
    DesktopWidgetKind.calendar: WidgetConfiguration(),
  };
  int writes = 0;
  @override
  Future<WidgetConfiguration> load(DesktopWidgetKind kind) async =>
      values[kind]!;
  @override
  Future<void> save(DesktopWidgetKind kind, WidgetConfiguration config) async {
    writes++;
    values[kind] = config;
  }
}

class FixtureCompanion extends NativeWidgetService {
  int reloads = 0;
  @override
  bool get isAvailable => true;
  @override
  Future<WidgetControlState> readSettings() async => const WidgetControlState();
  @override
  Future<void> reloadConfiguration() async {
    reloads++;
  }
}

class FailingWidgetConfigurations extends MemoryWidgetConfigurations {
  @override
  Future<void> save(DesktopWidgetKind kind, WidgetConfiguration config) async {
    if (kind == DesktopWidgetKind.calendar) {
      throw const FileSystemException('Synthetic save failure');
    }
    await super.save(kind, config);
  }
}

void main() {
  testWidgets(
    'external widget requests route to the correct editor and protect dirty drafts',
    (tester) async {
      final store = MemoryWidgetConfigurations();
      final service = FixtureCompanion();
      var kind = DesktopWidgetKind.tasks;
      var revision = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SingleChildScrollView(
                  child: WidgetSettingsPage(
                    service: service,
                    store: store,
                    initialKind: kind,
                    requestRevision: revision,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Customize Tasks Widget'), findsOneWidget);
      update(() {
        kind = DesktopWidgetKind.calendar;
        revision++;
      });
      await tester.pumpAndSettle();
      expect(find.text('Customize Calendar Widget'), findsOneWidget);
      expect(find.text('Customize Tasks Widget'), findsNothing);
      await tester.tap(find.text('Show widget title'));
      await tester.pumpAndSettle();
      update(() {
        kind = DesktopWidgetKind.tasks;
        revision++;
      });
      await tester.pumpAndSettle();
      expect(find.text('Discard unapplied widget changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Customize Calendar Widget'), findsOneWidget);
      update(() {
        revision++;
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard and switch'));
      await tester.pumpAndSettle();
      expect(find.text('Customize Tasks Widget'), findsOneWidget);
      update(() {
        revision++;
      });
      await tester.pumpAndSettle();
      expect(find.byType(WidgetConfigurationEditor), findsOneWidget);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Apply All rolls back the first configuration when the second save fails',
    (tester) async {
      final store = FailingWidgetConfigurations();
      final service = FixtureCompanion();
      final before = store.values[DesktopWidgetKind.tasks]!.toJson();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WidgetSettingsPage(service: service, store: store),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure tasks widget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show widget title'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to All Widgets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to All Widgets').last);
      await tester.pumpAndSettle();
      expect(store.values[DesktopWidgetKind.tasks]!.toJson(), before);
      expect(service.reloads, 0);
      expect(
        find.textContaining('Could not save widget settings'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Apply All uses current visibility and preserves calendar-only surfaces',
    (tester) async {
      final store = MemoryWidgetConfigurations();
      final service = FixtureCompanion();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WidgetSettingsPage(service: service, store: store),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure tasks widget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show widget title'));
      await tester.pumpAndSettle();
      store.values[DesktopWidgetKind.tasks] = store
          .values[DesktopWidgetKind.tasks]!
          .copyWith(enabled: false);
      store.values[DesktopWidgetKind.calendar] = store
          .values[DesktopWidgetKind.calendar]!
          .copyWith(
            enabled: true,
            surfaces: {'agenda': const WidgetSurface(opacity: 42)},
          );
      await tester.tap(find.text('Apply to All Widgets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to All Widgets').last);
      await tester.pumpAndSettle();
      expect(store.values[DesktopWidgetKind.tasks]!.enabled, isFalse);
      expect(store.values[DesktopWidgetKind.calendar]!.enabled, isTrue);
      expect(
        store.values[DesktopWidgetKind.calendar]!.surfaces['agenda']!.opacity,
        42,
      );
      expect(store.values[DesktopWidgetKind.calendar]!.showTitle, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Apply persists only selected widget, Apply All preserves layouts, Cancel writes nothing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryWidgetConfigurations();
      final service = FixtureCompanion();
      final capture = GlobalKey();
      final fontFile = Platform.environment['TODORBIT_UI_FONT'];
      if (fontFile != null) {
        await tester.runAsync(() async {
          final font = FontLoader('Capture');
          font.addFont(
            File(fontFile)
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          );
          await font.load();
          final iconFile = Platform.environment['TODORBIT_UI_ICONS'];
          if (iconFile != null) {
            final icons = FontLoader('MaterialIcons');
            icons.addFont(
              File(iconFile)
                  .readAsBytes()
                  .then((bytes) => ByteData.sublistView(bytes)),
            );
            await icons.load();
          }
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              fontFamily: fontFile == null ? null : 'Capture',
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: WidgetSettingsPage(service: service, store: store),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure tasks widget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show widget title'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(store.values[DesktopWidgetKind.tasks]!.showTitle, isFalse);
      expect(store.values[DesktopWidgetKind.calendar]!.showTitle, isTrue);
      expect(service.reloads, 1);
      await tester.tap(find.text('Configure calendar widget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Open App button'));
      await tester.pumpAndSettle();
      if (Platform.environment['TODORBIT_UI_CAPTURE'] case final output?) {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ImageByteFormat.png);
          await File(output).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Apply to All Widgets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to All Widgets').last);
      await tester.pumpAndSettle();
      expect(store.values[DesktopWidgetKind.tasks]!.showOpenButton, isFalse);
      expect(store.values[DesktopWidgetKind.tasks]!.showTitle, isTrue);
      expect(
        store.values[DesktopWidgetKind.tasks]!.navigationPosition,
        WidgetNavigationPosition.right,
      );
      expect(store.values[DesktopWidgetKind.tasks]!.enabled, isTrue);
      expect(store.values[DesktopWidgetKind.calendar]!.enabled, isFalse);
      expect(service.reloads, 2);
      expect(store.writes, 3);
      await tester.tap(find.text('Configure tasks widget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show widget title'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.writes, 3);
      expect(store.values[DesktopWidgetKind.tasks]!.showTitle, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
