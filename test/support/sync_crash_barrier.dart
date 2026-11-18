import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<void> terminateSyncWorkerAtBarrier(Process child, File marker) async {
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
