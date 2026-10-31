import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/widget_configuration_store.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/features/shared/download_size.dart';

void main() {
  test(
    'production widget enabled flags survive reload and additive migration',
    () async {
      final directory = await Directory.systemTemp.createTemp('widget-hotfix-');
      addTearDown(() => directory.delete(recursive: true));
      final store = WidgetConfigurationStore(directory);
      for (final tasks in [true, false]) {
        for (final calendar in [true, false]) {
          for (final kind in DesktopWidgetKind.values) {
            final config = WidgetConfiguration(
              enabled: kind == DesktopWidgetKind.tasks ? tasks : calendar,
              layoutLocked: true,
              navigationOrder: const ['upcoming', 'all', 'today', 'inbox'],
              surfaces: {'shell': const WidgetSurface(opacity: 65)},
            );
            await store.save(kind, config);
            final file = File(
              '${directory.path}/widget-${kind.name}-configuration.json',
            );
            final bytes = await file.readAsBytes();
            final reopened = await WidgetConfigurationStore(directory)
                .load(kind);
            expect(reopened.toJson(), config.toJson());
            expect(await file.readAsBytes(), bytes);
            final older = config.toJson()..remove('enabled');
            await file.writeAsString(jsonEncode(older));
            final migrated = await store.load(kind);
            expect(migrated.enabled, kind == DesktopWidgetKind.tasks);
            expect(migrated.layoutLocked, isTrue);
            expect(migrated.surfaces['shell']!.opacity, 65);
            expect(jsonDecode(await file.readAsString()), older);
          }
        }
      }
    },
  );
  test('legacy calendar modes load as the unified design without resetting settings', () {
    for (final mode in ['compactAgenda', 'fullMonth', 'unknown', null]) {
      final old = WidgetConfiguration(
        enabled: true,
        textScale: 1.3,
        layoutLocked: true,
        surfaces: {'shell': const WidgetSurface(opacity: 35)},
      ).toJson();
      old['calendarPresentation'] = mode;
      final loaded = WidgetConfiguration.fromJson(old);
      expect(loaded.enabled, isTrue);
      expect(loaded.layoutLocked, isTrue);
      expect(loaded.textScale, 1.3);
      expect(loaded.surfaces['shell']!.opacity, 35);
      expect(loaded.toJson().containsKey('calendarPresentation'), isFalse);
    }
  });
  test('partial appearance maps retain additive indicator defaults', () {
    final config = WidgetConfiguration(
      surfaces: {'shell': const WidgetSurface(opacity: 30)},
    );
    expect(config.surfaces['shell']!.opacity, 30);
    expect(config.surfaces['selectedDate'], isNotNull);
    expect(config.surfaces['today']!.border, isTrue);
  });
  test(
    'Decimal download sizes share units, handle unknowns and remain bounded',
    () {
      expect(
        formatDownloadSize(17150980, total: 47132241),
        '17.2 MB / 47.1 MB',
      );
      expect(formatDownloadSize(0), '0 B');
      expect(formatDownloadSize(3, total: 5), '3 B / 5 B');
      expect(formatDownloadSize(1024, total: 0), '1 KB');
      expect(formatDownloadSize(0, total: 1048576), '0 MB / 1 MB');
      expect(formatDownloadSize(1048576, total: 1048576), '1 MB / 1 MB');
      expect(formatDownloadSize(-1), 'Unknown size');
      expect(formatDownloadSize(1024, total: -10), '1 KB');
      expect(formatDownloadSize(9223372036854775807), endsWith(' TB'));
      expect(formatDownloadSize(1024 * 1024 * 1024), '1.1 GB');
    },
  );
  test(
    'configuration validates malformed values and preserves hidden navigation',
    () {
      final c = WidgetConfiguration.fromJson({
        'showTitle': false,
        'showOpenButton': false,
        'views': [],
        'textScale': 999,
        'navigationPosition': 'right',
        'navigationDisplay': 'icons',
        'surfaces': {
          'shell': {
            'opacity': -1,
            'radius': 999,
            'color': 'script',
            'thickness': 100,
          },
        },
      });
      expect(c.hasHeader, isFalse);
      expect(c.views, isEmpty);
      expect(c.textScale, 1.6);
      expect(c.surfaces['shell']!.opacity, 0);
      expect(c.surfaces['shell']!.radius, 32);
      expect(c.surfaces['shell']!.color, isNull);
      expect(
        WidgetConfiguration.fromJson(jsonDecode(jsonEncode(c.toJson())))
            .toJson(),
        c.toJson(),
      );
    },
  );
  test(
    'shared appearance preserves per-widget lifecycle, navigation and cells',
    () {
      final calendar = WidgetConfiguration(
        enabled: true,
        navigationPosition: WidgetNavigationPosition.right,
        views: [],
        layoutLocked: true,
        surfaces: {
          ...WidgetConfiguration.defaults,
          'calendarCell': const WidgetSurface(opacity: 42),
          'agenda': const WidgetSurface(opacity: 43),
        },
      );
      final tasks = WidgetConfiguration(
        showTitle: false,
        showOpenButton: false,
        textScale: 1.4,
        surfaces: {
          ...WidgetConfiguration.defaults,
          'shell': const WidgetSurface(opacity: 25),
        },
      );
      final updated = calendar.withSharedAppearance(tasks);
      expect(updated.enabled, isTrue);
      expect(updated.layoutLocked, isTrue);
      expect(updated.views, isEmpty);
      expect(updated.navigationPosition, WidgetNavigationPosition.right);
      expect(updated.surfaces['calendarCell']!.opacity, 42);
      expect(updated.surfaces['agenda']!.opacity, 43);
      expect(updated.surfaces['shell']!.opacity, 25);
      expect(updated.hasHeader, isFalse);
    },
  );
  test('legacy migration is deterministic, separate and leaves original bytes intact', () async {
    final dir = await Directory.systemTemp.createTemp(
      'todorbit-widget-config-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final legacy = File('${dir.path}/widget-settings.json');
    const original =
        '{"x":123,"width":376,"layoutLocked":true,"backgroundOpacity":35,"launchAtSignIn":false}';
    await legacy.writeAsString(original);
    final store = WidgetConfigurationStore(dir);
    final tasks = await store.load(DesktopWidgetKind.tasks);
    expect(tasks.enabled, isTrue);
    expect(tasks.layoutLocked, isTrue);
    expect(tasks.surfaces['shell']!.opacity, 35);
    final calendar = await store.load(DesktopWidgetKind.calendar);
    expect(calendar.enabled, isFalse);
    expect(calendar.layoutLocked, isFalse);
    await store.save(DesktopWidgetKind.tasks, tasks.copyWith(showTitle: false));
    await store.save(
      DesktopWidgetKind.calendar,
      calendar.copyWith(enabled: true),
    );
    expect((await store.load(DesktopWidgetKind.tasks)).showTitle, isFalse);
    expect((await store.load(DesktopWidgetKind.calendar)).enabled, isTrue);
    expect(await legacy.readAsString(), original);
    final file = File('${dir.path}/widget-calendar-configuration.json');
    await file.writeAsString('{"version":999}');
    await expectLater(
      store.load(DesktopWidgetKind.calendar),
      throwsFormatException,
    );
    expect(await file.readAsString(), '{"version":999}');
  });
  test(
    'legacy appearance opacity wins and atomic saves replace an existing file',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'todorbit-widget-migration-',
      );
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/widget-settings.json')
          .writeAsString('{"backgroundOpacity":35,"launchAtSignIn":false}');
      const appearance = '{"widgetOpacity":64,"theme":"dark"}';
      await File('${dir.path}/appearance-settings.json')
          .writeAsString(appearance);
      final store = WidgetConfigurationStore(dir);
      final config = await store.load(DesktopWidgetKind.tasks);
      expect(config.surfaces['shell']!.opacity, 64);
      await store.save(DesktopWidgetKind.tasks, config);
      await store.save(
        DesktopWidgetKind.tasks,
        config.copyWith(showTitle: false),
      );
      expect((await store.load(DesktopWidgetKind.tasks)).showTitle, isFalse);
      expect(
        await File('${dir.path}/appearance-settings.json').readAsString(),
        appearance,
      );
      expect(
        await dir.list().where((f) => f.path.endsWith('.tmp')).isEmpty,
        isTrue,
      );
    },
  );
}
