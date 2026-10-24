import 'dart:convert';
import 'dart:io';

/// Starts the Windows helper and waits until it has accepted the handoff.
/// The caller may close the app only after this future completes.
Future<void> startUpdateHelper({
  required File script,
  required List<String> arguments,
  required File readyFile,
  required File resultFile,
  Duration timeout = const Duration(seconds: 20),
}) async {
  if (await readyFile.exists()) await readyFile.delete();
  if (await resultFile.exists()) await resultFile.delete();
  // On the tested Windows setup, Dart's detached mode returned a PID without
  // executing PowerShell. A normal child remained alive after its parent exit.
  final process = await Process.start('powershell.exe', [
    '-NoProfile',
    '-WindowStyle',
    'Hidden',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    script.path,
    ...arguments,
  ]);
  final stderr = StringBuffer();
  process.stdout.drain<void>();
  process.stderr.transform(utf8.decoder).listen(stderr.write);
  int? exitCode;
  process.exitCode.then((value) => exitCode = value);
  final deadline = DateTime.now().add(timeout);
  while (true) {
    if (await readyFile.exists()) {
      await readyFile.delete();
      return;
    }
    if (await resultFile.exists()) {
      throw StateError((await resultFile.readAsString()).trim());
    }
    if (exitCode != null) {
      throw StateError(
        'Update helper exited ($exitCode): ${stderr.toString().trim()}',
      );
    }
    if (DateTime.now().isAfter(deadline)) {
      process.kill();
      throw StateError(
        'Update helper did not become ready. Todorbit is still running.',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
