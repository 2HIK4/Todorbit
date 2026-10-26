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
  bool previewAvailable = true;
  @override
  bool get isAvailable => true;
  final previews = <(DesktopWidgetKind, WidgetConfiguration, bool)>[];
  @override
  Future<bool> previewConfiguration({
    required DesktopWidgetKind kind,
    required String session,
    required int sequence,
    required WidgetConfiguration baseline,
    required WidgetConfiguration configuration,
    bool end = false,
  }) async {
    previews.add((kind, configuration, end));
    return previewAvailable;
  }

  @override
  Future<WidgetControlState> readSettings() async => const WidgetControlState();
  @override
  Future<void> setWidgetVisible(DesktopWidgetKind kind, bool visible) async {}
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
    'continuous slider movement previews before pointer release without disk writes',
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
      await tester.ensureVisible(find.text('Typography'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Typography'));
      await tester.pumpAndSettle();
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      service.previews.clear();
      final bounds = tester.getRect(slider);
      final gesture = await tester.startGesture(
        Offset(bounds.left + 24, bounds.center.dy),
      );
      for (var step = 0; step < 10; step++) {
        await gesture.moveBy(Offset((bounds.width - 48) / 12, 0));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        service.previews.where((entry) => !entry.$3).length,
        greaterThanOrEqualTo(2),
      );
      expect(store.writes, 0);
      await gesture.up();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'preview reconnect clears stale unavailable feedback without saving',
    (tester) async {
      final store = MemoryWidgetConfigurations();
      final service = FixtureCompanion()..previewAvailable = false;
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
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.textContaining('Live preview unavailable'), findsOneWidget);
      service.previewAvailable = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.textContaining('Live preview unavailable'), findsNothing);
      expect(store.writes, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('visibility changes preserve current external preferences', (
    tester,
  ) async {
    final store = MemoryWidgetConfigurations();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WidgetSettingsPage(
              service: FixtureCompanion(),
              store: store,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    store.values[DesktopWidgetKind.tasks] = store
        .values[DesktopWidgetKind.tasks]!
        .copyWith(showTitle: false, textScale: 1.4, layoutLocked: true);
    final toggle = find.descendant(
      of: find.widgetWithText(ListTile, 'Tasks Widget'),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final saved = store.values[DesktopWidgetKind.tasks]!;
    expect(saved.enabled, isFalse);
    expect(saved.showTitle, isFalse);
    expect(saved.textScale, 1.4);
    expect(saved.layoutLocked, isTrue);
  });

  for (final choice in [
    'Continue Editing',
    'Discard Changes',
    'Save Changes',
  ]) {
    testWidgets('unsaved close: $choice and real-widget preview lifecycle', (
      tester,
    ) async {
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
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.writes, 0);
      expect(service.previews.last.$1, DesktopWidgetKind.tasks);
      expect(service.previews.last.$2.showTitle, isFalse);
      expect(service.previews.last.$3, isFalse);
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved widget changes'), findsOneWidget);
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
      if (choice == 'Continue Editing') {
        expect(find.text('Customize Tasks Widget'), findsOneWidget);
        expect(store.writes, 0);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      } else {
        expect(find.text('Customize Tasks Widget'), findsNothing);
      }
      expect(store.writes, choice == 'Save Changes' ? 1 : 0);
      expect(
        store.values[DesktopWidgetKind.tasks]!.showTitle,
        choice != 'Save Changes',
      );
      expect(service.previews.last.$3, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Apply stays open and Cancel rolls back only changes after Apply',
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
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Customize Tasks Widget'), findsOneWidget);
      expect(find.text('All changes saved'), findsOneWidget);
      await tester.tap(find.text('Show Open App button'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.values[DesktopWidgetKind.tasks]!.showTitle, isFalse);
      expect(store.values[DesktopWidgetKind.tasks]!.showOpenButton, isTrue);
      expect(store.writes, 1);
      expect(service.previews.last.$3, isTrue);
    },
  );

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
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      update(() {
        kind = DesktopWidgetKind.tasks;
        revision++;
      });
      await tester.pumpAndSettle();
      expect(find.text('Unsaved widget changes'), findsOneWidget);
      await tester.tap(find.text('Continue Editing').last);
      await tester.pumpAndSettle();
      expect(find.text('Customize Calendar Widget'), findsOneWidget);
      update(() {
        revision++;
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard Changes'));
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
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
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
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
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
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(store.values[DesktopWidgetKind.tasks]!.showTitle, isFalse);
      expect(store.values[DesktopWidgetKind.calendar]!.showTitle, isTrue);
      expect(service.reloads, 1);
      expect(find.text('Customize Tasks Widget'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure calendar widget'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Show Open App button'));
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
      expect(find.text('Customize Calendar Widget'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure tasks widget'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Show widget title'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.writes, 3);
      expect(store.values[DesktopWidgetKind.tasks]!.showTitle, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
