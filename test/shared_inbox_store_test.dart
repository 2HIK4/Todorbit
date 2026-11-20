import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/shared_inbox_store.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDir;
  late SharedInboxStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('todorbit_inbox_test_');
    store = SharedInboxStore(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('empty store loads empty list', () async {
    final entries = await store.load();
    expect(entries, isEmpty);
  });

  test('ingests single PDF file with correct metadata and atomic persistence', () async {
    final pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]; // %PDF-1.4
    final entry = await store.addBytes(
      pdfBytes,
      displayName: 'Report 2026.pdf',
      mimeType: 'application/pdf',
    );

    expect(entry.displayName, 'Report 2026.pdf');
    expect(entry.mimeType, 'application/pdf');
    expect(entry.byteSize, pdfBytes.length);
    expect(entry.sha256, isNotEmpty);
    expect(await entry.fileIn(tempDir).exists(), isTrue);

    // Reload from new store instance pointing to same directory
    final freshStore = SharedInboxStore(tempDir);
    final loaded = await freshStore.load();
    expect(loaded.length, 1);
    expect(loaded.first.id, entry.id);
    expect(loaded.first.displayName, 'Report 2026.pdf');
    expect(loaded.first.byteSize, pdfBytes.length);
  });

  test('ingests image and infers MIME type from extension', () async {
    final imgBytes = List<int>.filled(500, 42);
    final entry = await store.addBytes(
      imgBytes,
      displayName: 'photo.PNG',
    );

    expect(entry.displayName, 'photo.PNG');
    expect(entry.mimeType, 'image/png');
    expect(entry.byteSize, 500);
  });

  test('ingests multiple mixed files sequentially and orders by date descending', () async {
    await store.addBytes([1, 2, 3], displayName: 'first.txt');
    // slight delay for timestamp difference
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await store.addBytes([4, 5, 6, 7], displayName: 'second.pdf');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await store.addBytes([8, 9], displayName: 'third.jpg');

    final loaded = await store.load();
    expect(loaded.length, 3);
    expect(loaded[0].displayName, 'third.jpg');
    expect(loaded[1].displayName, 'second.pdf');
    expect(loaded[2].displayName, 'first.txt');
  });

  test('detects duplicate content by SHA-256 and avoids duplicating storage', () async {
    final bytes = [10, 20, 30, 40, 50];
    final first = await store.addBytes(bytes, displayName: 'original.pdf');
    final second = await store.addBytes(bytes, displayName: 'duplicate.pdf');

    expect(second.id, first.id);
    expect(second.sha256, first.sha256);

    final loaded = await store.load();
    expect(loaded.length, 1);
  });

  test('sanitizes unsafe filenames and directory traversal', () {
    expect(
      SharedInboxStore.sanitizeFilename('../../etc/passwd.pdf'),
      'passwd.pdf',
    );
    expect(
      SharedInboxStore.sanitizeFilename('bad:name*with?chars.png'),
      'bad_name_with_chars.png',
    );
    expect(
      SharedInboxStore.sanitizeFilename('   ..   '),
      'shared_file',
    );
    expect(
      SharedInboxStore.sanitizeFilename(''),
      'shared_file',
    );
  });

  test('rejects files larger than 32 MiB limit', () async {
    // Generate dummy file larger than 32 MiB
    final largeFile = File(path.join(tempDir.path, 'large.bin'));
    // Open write stream with 33MB
    final sink = largeFile.openWrite();
    final chunk = List<int>.filled(1024 * 1024, 0); // 1MB chunk
    for (var i = 0; i < 33; i++) {
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();

    expect(
      () => store.addFile(largeFile),
      throwsA(isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        contains('32 MiB'),
      )),
    );
  });

  test('deletes single entry and removes file from disk', () async {
    final entry1 = await store.addBytes([1, 2], displayName: 'file1.txt');
    final entry2 = await store.addBytes([3, 4], displayName: 'file2.txt');

    expect((await store.load()).length, 2);
    expect(await entry1.fileIn(tempDir).exists(), isTrue);

    await store.deleteEntry(entry1.id);

    final remaining = await store.load();
    expect(remaining.length, 1);
    expect(remaining.first.id, entry2.id);
    expect(await entry1.fileIn(tempDir).exists(), isFalse);
    expect(await entry2.fileIn(tempDir).exists(), isTrue);
  });

  test('batch deletes entries and removes files from disk', () async {
    final entry1 = await store.addBytes([1], displayName: 'a.txt');
    final entry2 = await store.addBytes([2], displayName: 'b.txt');
    final entry3 = await store.addBytes([3], displayName: 'c.txt');

    await store.deleteEntries([entry1.id, entry3.id]);

    final remaining = await store.load();
    expect(remaining.length, 1);
    expect(remaining.first.id, entry2.id);
    expect(await entry1.fileIn(tempDir).exists(), isFalse);
    expect(await entry2.fileIn(tempDir).exists(), isTrue);
    expect(await entry3.fileIn(tempDir).exists(), isFalse);
  });

  test('cleanOrphans removes incomplete staging files and unindexed files', () async {
    final valid = await store.addBytes([1, 2, 3], displayName: 'valid.pdf');

    // Create a leftover staging file
    final orphanedStaging = File(path.join(store.stagingDirectory.path, 'leftover.tmp'));
    await orphanedStaging.writeAsString('partial');

    // Create an unindexed file in files directory
    final orphanedFile = File(path.join(store.filesDirectory.path, 'orphaned_unindexed.pdf'));
    await orphanedFile.writeAsString('orphan');

    expect(await orphanedStaging.exists(), isTrue);
    expect(await orphanedFile.exists(), isTrue);

    await store.cleanOrphans();

    expect(await orphanedStaging.exists(), isFalse);
    expect(await orphanedFile.exists(), isFalse);
    expect(await valid.fileIn(tempDir).exists(), isTrue);
  });
}
