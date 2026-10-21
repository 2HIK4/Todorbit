import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';

void main() {
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
