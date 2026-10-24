import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/update_helper_launcher.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'Windows helper acknowledges handoff and continues independently',
    () async {
      if (!Platform.isWindows) return;
      final folder = await Directory.systemTemp.createTemp('todorbit-handoff-');
      addTearDown(() => folder.delete(recursive: true));
      final script = File('${folder.path}/helper.ps1');
      final ready = File('${folder.path}/ready.txt');
      final result = File('${folder.path}/result.txt');
      await script.writeAsString('''
param([string]\$ReadyFile, [string]\$ResultFile)
Set-Content -LiteralPath \$ReadyFile -Value 'ready'
Start-Sleep -Seconds 1
Set-Content -LiteralPath \$ResultFile -Value 'finished'
''');
      await startUpdateHelper(
        script: script,
        arguments: ['-ReadyFile', ready.path, '-ResultFile', result.path],
        readyFile: ready,
        resultFile: result,
      );
      expect(await ready.exists(), isFalse);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!await result.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await result.readAsString(), contains('finished'));
    },
  );

  test('helper failure before handoff keeps caller informed', () async {
    if (!Platform.isWindows) return;
    final folder = await Directory.systemTemp.createTemp(
      'todorbit-handoff-fail-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final script = File('${folder.path}/helper.ps1');
    await script.writeAsString('exit 7');
    await expectLater(
      startUpdateHelper(
        script: script,
        arguments: const [],
        readyFile: File('${folder.path}/ready.txt'),
        resultFile: File('${folder.path}/result.txt'),
        timeout: const Duration(seconds: 5),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'bundled helper rejects an unregistered installer target before handoff',
    () async {
      if (!Platform.isWindows) return;
      final folder = await Directory.systemTemp.createTemp(
        'todorbit-install-preflight-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final target = Directory(path.join(folder.path, 'target'));
      await target.create();
      await File(path.join(target.path, 'Todorbit.exe'))
          .writeAsString('fixture');
      final package = File(path.join(folder.path, 'fixture.exe'));
      await package.writeAsString('fixture package');
      final digest = sha256.convert(await package.readAsBytes()).toString();
      final ready = File(path.join(folder.path, 'ready.txt'));
      final result = File(path.join(folder.path, 'last-install-result.txt'));
      await expectLater(
        startUpdateHelper(
          script: File('tools/update-helper.ps1').absolute,
          arguments: [
            '-Mode',
            'installed',
            '-Package',
            package.path,
            '-Target',
            target.path,
            '-Digest',
            digest,
            '-Size',
            '${await package.length()}',
            '-ParentPid',
            '999999',
            '-ReadyFile',
            ready.path,
            '-ExpectedVersion',
            '1.0.8',
          ],
          readyFile: ready,
          resultFile: result,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await ready.exists(), isFalse);
      expect(
        await result.readAsString(),
        contains('not the registered Todorbit installation'),
      );
    },
  );

  test('bundled helper identifies a conflicting app before handoff', () async {
    if (!Platform.isWindows) return;
    final folder = await Directory.systemTemp.createTemp(
      'todorbit-update-conflict-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final target = Directory(path.join(folder.path, 'target'));
    await target.create();
    final app = File(path.join(target.path, 'Todorbit.exe'));
    await File(Platform.environment['ComSpec']!).copy(app.path);
    final conflicting = await Process.start(app.path, ['/k', 'echo ready']);
    addTearDown(() async {
      conflicting.kill();
      await conflicting.exitCode;
    });
    final package = File(path.join(folder.path, 'fixture.zip'));
    await package.writeAsString('fixture package');
    final digest = sha256.convert(await package.readAsBytes()).toString();
    final ready = File(path.join(folder.path, 'ready.txt'));
    final result = File(path.join(folder.path, 'last-install-result.txt'));
    await expectLater(
      startUpdateHelper(
        script: File('tools/update-helper.ps1').absolute,
        arguments: [
          '-Mode',
          'portable',
          '-Package',
          package.path,
          '-Target',
          target.path,
          '-Digest',
          digest,
          '-Size',
          '${await package.length()}',
          '-ParentPid',
          '$pid',
          '-ReadyFile',
          ready.path,
          '-ExpectedVersion',
          '1.0.11',
        ],
        readyFile: ready,
        resultFile: result,
      ),
      throwsA(isA<StateError>()),
    );
    expect(await ready.exists(), isFalse);
    expect(await result.readAsString(), contains('PID ${conflicting.pid}'));
    expect(await app.exists(), isTrue);
  });
}
