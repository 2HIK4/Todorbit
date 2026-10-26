import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('live previews target the existing profile pipe without launching a process', () async {
    const channel = MethodChannel('life_manager/widget_preview');
    final messages = <List<dynamic>>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'send');
      messages.add(call.arguments as List<dynamic>);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final service = NativeWidgetService(
      launcher: (_, _) async => fail('Preview launched a process'),
    );
    final baseline = WidgetConfiguration(enabled: true);
    expect(
      await service.previewConfiguration(
        kind: DesktopWidgetKind.calendar,
        session: '00000000-0000-4000-8000-000000000001',
        sequence: 7,
        baseline: baseline,
        configuration: baseline.copyWith(textScale: 1.3),
      ),
      isTrue,
    );
    expect(messages.single[0], matches(RegExp(r'^[a-f0-9]{16}$')));
    final command = messages.single[1] as String;
    expect(command, startsWith('preview-configuration '));
    final envelope =
        jsonDecode(command.substring('preview-configuration '.length)) as Map;
    expect(envelope['kind'], 'calendar');
    expect(envelope['sequence'], 7);
    expect(envelope['configuration']['textScale'], 1.3);
    expect(envelope['baseline']['textScale'], 1);
    expect(envelope['end'], isFalse);
  });
  test('calendar visibility and configuration commands share the existing companion', () async {
    if (!Platform.isWindows) return;
    final dir = await Directory.systemTemp.createTemp(
      'todorbit-widget-routing-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final exe = File('${dir.path}/TodorbitWidget.exe');
    await exe.writeAsBytes([]);
    final commands = <String>[];
    final service = NativeWidgetService(
      widgetExecutable: exe.path,
      launcher: (_, args) async {
        commands.add(args[1]);
        return 0;
      },
    );
    await service.setWidgetVisible(DesktopWidgetKind.calendar, true);
    await service.setWidgetVisible(DesktopWidgetKind.calendar, false);
    await service.reloadConfiguration();
    expect(commands, [
      'calendar-show',
      'calendar-hide',
      'reload-configuration',
    ]);
  });
  test(
    'native widget commands use the packaged sibling and app path',
    () async {
      if (!Platform.isWindows) return;
      final directory = await Directory.systemTemp.createTemp(
        'life-manager-native-widget-test-',
      );
      final widget = File(
        '${directory.path}${Platform.pathSeparator}TodorbitWidget.exe',
      );
      await widget.writeAsBytes(const []);
      final calls = <(String, List<String>)>[];
      final service = NativeWidgetService(
        widgetExecutable: widget.path,
        appExecutable: r'C:\package\Todorbit.exe',
        launcher: (executable, arguments) async {
          calls.add((executable, arguments));
          return 0;
        },
      );
      try {
        await service.show();
        await service.ensureRemindersRunning();
        await service.quickAdd();
        await service.setView('all');
        await service.setView('upcoming');
        await service.setLayoutLocked(true);
        await service.setOpacity(70);
        await service.setLaunchAtSignIn(false);
        await service.close();
        expect(calls, hasLength(9));
        expect(calls.first.$1, widget.path);
        expect(calls.first.$2, [
          '--widget',
          '--app-exe',
          r'C:\package\Todorbit.exe',
        ]);
        expect(calls[1].$2, [
          '--widget',
          '--background',
          '--app-exe',
          r'C:\package\Todorbit.exe',
        ]);
        expect(calls[2].$2.take(2), ['--widget-command', 'quick-add']);
        expect(calls[3].$2.take(2), ['--widget-command', 'view-all']);
        expect(calls[4].$2.take(2), ['--widget-command', 'view-upcoming']);
        expect(calls[5].$2.take(2), ['--widget-command', 'layout-lock']);
        expect(calls[6].$2.take(2), ['--widget-command', 'opacity-70']);
        expect(calls[7].$2.take(2), ['--widget-command', 'startup-off']);
        expect(calls.last.$2.take(2), ['--widget-command', 'exit']);
        expect(() => service.setOpacity(101), throwsRangeError);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
