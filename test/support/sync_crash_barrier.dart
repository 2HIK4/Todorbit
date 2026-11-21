import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<void> runSyncCrashWorker({
  required String script,
  required File database,
  required File marker,
  required String stop,
  Map<String, String> environment = const {},
}) async {
  // Parallel dart run workers share the package's JIT native assets. Hold the
  // lock until exit because Windows cannot replace a loaded SQLite DLL.
  final lock = await File('.dart_tool/todorbit-sync-crash.lock')
      .open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.blockingExclusive);
    final child = await Process.start(
      'dart',
      ['run', script, database.path, marker.path, stop],
      runInShell: Platform.isWindows,
      environment: {
        ...environment,
        'APPDATA': '${marker.parent.path}/roaming',
        'LOCALAPPDATA': '${marker.parent.path}/local',
      },
    );
    await _terminateAtBarrier(child, marker);
  } finally {
    await lock.close();
  }
}

Future<void> _terminateAtBarrier(Process child, File marker) async {
  final output = child.stdout.transform(utf8.decoder).join();
  final errors = child.stderr.transform(utf8.decoder).join();
  int? exitCode;
  final exited = child.exitCode.then((code) => exitCode = code);
  var reachedBarrier = false;
  var terminated = false;
  try {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (exitCode == null &&
        !marker.existsSync() &&
        DateTime.now().isBefore(deadline)) {
      await Future.any([
        exited,
        Future<void>.delayed(const Duration(milliseconds: 50)),
      ]);
    }
    reachedBarrier = exitCode == null && marker.existsSync();
  } finally {
    if (exitCode == null) {
      terminated = Platform.isWindows
          ? (await Process.run('taskkill', [
                  '/PID',
                  '${child.pid}',
                  '/T',
                  '/F',
                ])).exitCode ==
                0
          : child.kill(ProcessSignal.sigkill);
    }
  }
  final code = await exited;
  final stdout = await output;
  final stderr = await errors;
  if (!reachedBarrier || !terminated) {
    fail(
      'Worker barrier reached: $reachedBarrier. Forced exit: $terminated. '
      'Exit code: $code.\nstdout:\n$stdout\nstderr:\n$stderr',
    );
  }
}
