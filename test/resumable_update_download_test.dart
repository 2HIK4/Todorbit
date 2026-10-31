import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/resumable_update_download.dart';

void main() {
  late HttpServer server;
  late Directory folder;
  late File target;
  late Uri uri;
  late ResumableUpdateDownload transfer;
  final bytes = List<int>.generate(8192, (i) => i % 251);
  final digest = sha256.convert(bytes).toString();

  Future<File> download({
    void Function(int, int)? progress,
    void Function(String)? state,
  }) => transfer.download(
    uri: uri,
    target: target,
    size: bytes.length,
    digest: digest,
    version: '1.0.20+24',
    progress: progress ?? (_, _) {},
    state: state,
  );
  Future<void> seed({
    int count = 3000,
    String? validator,
    bool corrupt = false,
  }) async {
    await File('${target.path}.part').writeAsBytes(
      corrupt ? List.filled(count, 0) : bytes.take(count).toList(),
    );
    await File('${target.path}.part.json').writeAsString(
      jsonEncode({
        ...ResumableUpdateDownload.identity(
          uri,
          bytes.length,
          digest,
          '1.0.20+24',
        ),
        'validator': ?validator,
      }),
    );
  }

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    folder = await Directory.systemTemp.createTemp('update-range-');
    target = File('${folder.path}/update.apk');
    uri = Uri.parse('http://127.0.0.1:${server.port}/asset');
    transfer = ResumableUpdateDownload(approved: (u) => u.host == '127.0.0.1');
  });
  tearDown(() async {
    transfer.pause();
    await server.close(force: true);
    await folder.delete(recursive: true);
  });

  test('process recovery uses exact saved byte count, Range and If-Range; verifies full checksum', () async {
    await seed(validator: '"immutable"');
    server.listen((request) async {
      expect(request.headers.value('range'), 'bytes=3000-');
      expect(request.headers.value('if-range'), '"immutable"');
      request.response.statusCode = 206;
      request.response.headers.set('etag', '"immutable"');
      request.response.headers.set('content-range', 'bytes 3000-8191/8192');
      request.response.add(bytes.sublist(3000));
      await request.response.close();
    });
    final seen = <int>[];
    expect(
      await transfer.saved(
        target,
        ResumableUpdateDownload.identity(
          uri,
          bytes.length,
          digest,
          '1.0.20+24',
        ),
      ),
      3000,
    );
    final file = await download(progress: (n, _) => seen.add(n));
    expect(seen.first, 3000);
    expect(await file.readAsBytes(), bytes);
    expect(await File('${target.path}.part').exists(), isFalse);
  });

  test('pause retains bytes and new service resumes; discard removes only transfer state', () async {
    final firstSent = Completer<void>();
    var requests = 0;
    server.listen((request) async {
      requests++;
      if (requests == 1) {
        request.response.bufferOutput = false;
        request.response.add(bytes.sublist(0, 3000));
        await request.response.flush();
        await firstSent.future;
        try {
          await request.response.close();
        } catch (_) {}
      } else {
        request.response.statusCode = 206;
        request.response.headers.set('content-range', 'bytes 3000-8191/8192');
        request.response.add(bytes.sublist(3000));
        await request.response.close();
      }
    });
    await expectLater(
      download(
        progress: (n, _) {
          if (n >= 3000) {
            transfer.pause();
            firstSent.complete();
          }
        },
      ),
      throwsA(isA<UpdateDownloadPaused>()),
    );
    expect(await File('${target.path}.part').length(), 3000);
    transfer = ResumableUpdateDownload(approved: (u) => u.host == '127.0.0.1');
    expect(await (await download()).readAsBytes(), bytes);
    await seed();
    await transfer.discard(target);
    expect(await target.exists(), isTrue);
    expect(await File('${target.path}.part').exists(), isFalse);
    expect(await File('${target.path}.part.json').exists(), isFalse);
  });

  test('ignored Range safely truncates and explains restart', () async {
    await seed();
    server.listen((r) async {
      r.response.add(bytes);
      await r.response.close();
    });
    final notices = <String>[];
    expect(await (await download(state: notices.add)).readAsBytes(), bytes);
    expect(notices.first, contains('restarting from zero'));
  });

  test('real process termination preserves bytes for a new downloader', () async {
    final killed = Completer<void>();
    var requests = 0;
    server.listen((r) async {
      requests++;
      if (requests == 1) {
        r.response.bufferOutput = false;
        r.response.add(bytes.sublist(0, 3000));
        await r.response.flush();
        await killed.future;
        try {
          await r.response.close();
        } catch (_) {}
      } else {
        expect(r.headers.value('range'), 'bytes=3000-');
        r.response.statusCode = 206;
        r.response.headers.set('content-range', 'bytes 3000-8191/8192');
        r.response.add(bytes.sublist(3000));
        await r.response.close();
      }
    });
    final executable = File(Platform.resolvedExecutable);
    final dart = executable.path.endsWith('flutter_tester.exe')
        ? '${executable.parent.parent.parent.parent.path}/dart-sdk/bin/dart.exe'
        : executable.path;
    final child = await Process.start(dart, [
      '--packages=.dart_tool/package_config.json',
      'test/fixtures/update_download_worker.dart',
      uri.toString(),
      target.path,
      '${bytes.length}',
      digest,
    ]);
    final errors = child.stderr.transform(utf8.decoder).join();
    addTearDown(() {
      child.kill();
      if (!killed.isCompleted) killed.complete();
    });
    final amount = await child.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    expect(amount, '3000');
    expect(child.kill(), isTrue);
    await child.exitCode;
    expect(await errors, isEmpty);
    killed.complete();
    expect(await File('${target.path}.part').length(), 3000);
    expect(await (await download()).readAsBytes(), bytes);
  });

  for (final mode in [
    'wrong start',
    'wrong total',
    'changed validator',
    '416',
    '503',
  ]) {
    test('$mode never appends or offers an installable package', () async {
      await seed(validator: '"one"');
      server.listen((r) async {
        r.response.statusCode = mode == '416'
            ? 416
            : mode == '503'
            ? 503
            : 206;
        r.response.headers.set(
          'etag',
          mode == 'changed validator' ? '"two"' : '"one"',
        );
        r.response.headers.set(
          'content-range',
          mode == 'wrong start'
              ? 'bytes 0-8191/8192'
              : mode == 'wrong total'
              ? 'bytes 3000-8191/9999'
              : 'bytes 3000-8191/8192',
        );
        await r.response.close();
      });
      await expectLater(
        download(),
        throwsA(anyOf(isA<Exception>(), isA<StateError>())),
      );
      expect(await File('${target.path}.part').length(), 3000);
      expect(await target.exists(), isFalse);
    });
  }

  test('corrupt retained prefix fails full hash and is discarded', () async {
    await seed(corrupt: true);
    server.listen((r) async {
      r.response.statusCode = 206;
      r.response.headers.set('content-range', 'bytes 3000-8191/8192');
      r.response.add(bytes.sublist(3000));
      await r.response.close();
    });
    await expectLater(download(), throwsStateError);
    expect(await target.exists(), isFalse);
    expect(await File('${target.path}.part').exists(), isFalse);
  });

  test('different asset digest cannot reuse old prefix', () async {
    await seed();
    final metadata = File('${target.path}.part.json');
    final data =
        jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
    data['sha256'] = '0' * 64;
    await metadata.writeAsString(jsonEncode(data));
    server.listen((r) async {
      expect(r.headers.value('range'), isNull);
      r.response.add(bytes);
      await r.response.close();
    });
    expect(await (await download()).readAsBytes(), bytes);
  });

  test('network failure retains actual bytes; complete partial recovers without HTTP', () async {
    await seed();
    server.listen((r) async {
      r.response.statusCode = 503;
      await r.response.close();
    });
    await expectLater(download(), throwsA(isA<HttpException>()));
    expect(await File('${target.path}.part').length(), 3000);
    await seed(count: bytes.length);
    expect(await (await download()).readAsBytes(), bytes);
  });
}
