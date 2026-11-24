import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  final directory = Directory(
    Platform.environment['TODORBIT_REFINEMENT_REPORT'] ??
        (throw StateError('Set TODORBIT_REFINEMENT_REPORT')),
  );
  await directory.create(recursive: true);
  final driver = await FlutterDriver.connect() as VMServiceFlutterDriver;
  final service = driver.serviceClient;
  final isolate = (await service.getVM()).isolates!.firstWhere(
    (item) => item.name == 'main',
  );
  final isolateId = isolate.id!;
  final period = find.byValueKey('calendar-period-label');
  final stats = <String, Object>{};
  const timeout = Duration(seconds: 12);
  Future<void> tap(SerializableFinder target) =>
      driver.tap(target, timeout: timeout);
  Future<void> text(String label) => tap(find.text(label));
  Future<void> capture(String label) async =>
      File(path.join(directory.path, '$label.png'))
          .writeAsBytes(await driver.screenshot());
  Future<void> measure(String name, Future<void> Function() action) async {
    final start = (await service.getVMTimelineMicros()).timestamp!;
    var elapsed = Duration.zero;
    final trace = await driver.traceAction(() async {
      final stopwatch = Stopwatch()..start();
      await action();
      await driver.waitUntilNoTransientCallbacks(timeout: timeout);
      elapsed = stopwatch.elapsed;
    });
    final end = (await service.getVMTimelineMicros()).timestamp!;
    final samples = await service.getCpuSamples(isolateId, start, end - start);
    final summary = TimelineSummary.summarize(trace);
    stats[name] = {
      'driverElapsedMs': elapsed.inMilliseconds,
      'cpuSamples': samples.sampleCount,
      'frames': summary.countFrames(),
      if (summary.countFrames() > 0) 'timeline': summary.summaryJson,
    };
    for (final (label, value) in [
      ('trace', trace.json),
      ('cpu', samples.json),
    ]) {
      await File(path.join(directory.path, '$name-$label.json'))
          .writeAsString(jsonEncode(value));
    }
    stdout.writeln('$name captured');
  }

  try {
    await driver.waitUntilFirstFrameRasterized();
    await _maximizeTestWindow();
    await driver.waitFor(find.text('All tasks'), timeout: timeout);
    await measure('first-open', () async {
      await text('Calendar');
      await driver.waitFor(period, timeout: timeout);
    });
    await capture('calendar-week-dark');
    await measure('day', () => text('Day'));
    await capture('calendar-day-dark');
    await measure(
      'day-scroll',
      () => driver.scroll(
        find.descendant(
          of: find.byType('CalendarDayView'),
          matching: find.byType('SingleChildScrollView'),
          firstMatchOnly: true,
        ),
        0,
        -530,
        const Duration(milliseconds: 360),
        timeout: timeout,
      ),
    );
    await measure('day-zoom', () => tap(find.byTooltip('Zoom in time slots')));
    await measure('month', () => text('Month'));
    await capture('calendar-month-dark');
    await measure('month-next', () => tap(find.byTooltip('Next period')));
    await measure(
      'month-previous',
      () => tap(find.byTooltip('Previous period')),
    );
    await measure('week', () => text('Week'));
    await text('All tasks');
    await capture('all-tasks-dark');
    final memoryBefore = await service.getMemoryUsage(isolateId);
    await measure('repeated-open', () async {
      for (var i = 0; i < 6; i++) {
        await text('Calendar');
        await driver.waitFor(period, timeout: timeout);
        await text('All tasks');
      }
    });
    final memoryAfter = await service.getMemoryUsage(isolateId);
    stats['memory'] = {
      'before': memoryBefore.json!,
      'after': memoryAfter.json!,
    };
    await text('Upcoming');
    await capture('upcoming-dark');
    await text('Settings');
    await text('Light');
    await tap(find.byTooltip('Close Settings'));
    await capture('upcoming-light');
    await text('All tasks');
    await capture('all-tasks-light');
    await text('Calendar');
    await capture('calendar-week-light');
  } finally {
    await File(path.join(directory.path, 'summary.json'))
        .writeAsString(const JsonEncoder.withIndent('  ').convert(stats));
    await driver.close();
  }
}

Future<void> _maximizeTestWindow() async {
  final executable = Platform.environment['TODORBIT_REFINEMENT_EXE']!;
  final result = await Process.run(
    'powershell.exe',
    [
      '-NoProfile',
      '-Command',
      r'''

Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int command);' -Name Window -Namespace TodorbitProfile
$app = Get-Process -Name Todorbit | Where-Object { $_.Path -eq $env:TODORBIT_REFINEMENT_EXE -and $_.MainWindowHandle -ne 0 }
if (@($app).Count -ne 1) { throw 'Expected one isolated Todorbit window' }
[TodorbitProfile.Window]::ShowWindowAsync($app.MainWindowHandle, 3) | Out-Null
''',
    ],
    environment: {'TODORBIT_REFINEMENT_EXE': executable},
  );
  if (result.exitCode != 0) {
    throw StateError('Could not maximize the isolated test window: $result');
  }
}
