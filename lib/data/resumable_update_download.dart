import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class UpdateDownloadPaused implements Exception {
  const UpdateDownloadPaused();
  @override
  String toString() => 'Download paused. Saved bytes are retained; tap Resume.';
}

/// A private, persisted transfer. Only a length/hash-verified file is promoted.
/// The on-disk length is authoritative after process death, not a percentage.
class ResumableUpdateDownload {
  ResumableUpdateDownload({
    required this.approved,
    HttpClient Function()? client,
  }) : createClient = client ?? HttpClient.new;
  final bool Function(Uri) approved;
  final HttpClient Function() createClient;
  HttpClient? _client;
  bool _paused = false;
  String? notice;
  bool verifying = false;
  bool get running => _client != null;

  void pause() {
    _paused = true;
    _client?.close(force: true);
  }

  static Map<String, Object> identity(
    Uri uri,
    int size,
    String digest,
    String version,
  ) => {
    'format': 1,
    'uri': uri.toString(),
    'size': size,
    'sha256': digest,
    'version': version,
  };

  Future<int> saved(File target, Map<String, Object> identity) async {
    final partial = File('${target.path}.part');
    final metadata = File('${target.path}.part.json');
    try {
      if (await target.exists() &&
          await target.length() == identity['size'] &&
          (await sha256.bind(target.openRead()).first).toString() ==
              identity['sha256']) {
        return identity['size'] as int;
      }
      final stored = jsonDecode(await metadata.readAsString()) as Map;
      if (identity.entries.any((e) => stored[e.key] != e.value)) return 0;
      final length = await partial.length();
      return length <= (identity['size'] as int) ? length : 0;
    } on FileSystemException {
      return 0;
    } on FormatException {
      return 0;
    } on TypeError {
      return 0;
    }
  }

  Future<void> discard(File target) async {
    if (running) throw StateError('Pause the download before discarding it.');
    for (final suffix in ['.part', '.part.json', '.part.json.tmp']) {
      final file = File('${target.path}$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  Future<File> download({
    required Uri uri,
    required File target,
    required int size,
    required String digest,
    required String version,
    required void Function(int, int) progress,
    void Function(String)? state,
  }) async {
    if (running) throw StateError('A download is already running.');
    if (!approved(uri)) throw StateError('Unapproved update source.');
    _paused = false;
    notice = null;
    verifying = false;
    final client = _client = createClient();
    client.autoUncompress = false;
    final partial = File('${target.path}.part');
    final metadata = File('${target.path}.part.json');
    final key = identity(uri, size, digest, version);
    Future<void> persist(Map<String, dynamic> value) async {
      final temporary = File('${metadata.path}.tmp');
      await temporary.writeAsString(jsonEncode(value), flush: true);
      await temporary.rename(metadata.path);
    }

    Future<bool> valid(File file) async =>
        await file.exists() &&
        await file.length() == size &&
        (await sha256.bind(file.openRead()).first).toString() == digest;
    try {
      await target.parent.create(recursive: true);
      if (await valid(target)) {
        progress(size, size);
        return target;
      }
      var offset = await saved(target, key);
      Map<String, dynamic> stored = {...key};
      if (offset > 0) {
        stored = Map<String, dynamic>.from(
          jsonDecode(await metadata.readAsString()) as Map,
        );
      }
      if (offset == 0) {
        await partial.writeAsBytes([], flush: true);
        await persist(stored);
      }
      progress(offset, size);
      // A crash may have occurred after the last byte but before promotion.
      if (offset == size && await valid(partial)) {
        verifying = true;
        progress(size, size);
        state?.call('Verifying download…');
      } else {
        var location = uri;
        HttpClientResponse? response;
        for (var redirects = 0; redirects < 6; redirects++) {
          if (_paused) throw const UpdateDownloadPaused();
          if (!approved(location)) {
            throw StateError('Unapproved update redirect.');
          }
          final request = await client
              .getUrl(location)
              .timeout(const Duration(seconds: 20));
          request.followRedirects = false;
          request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
          request.headers.set(HttpHeaders.userAgentHeader, 'Todorbit-Updater');
          if (offset > 0) {
            request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
            if (stored['validator'] case final String validator) {
              request.headers.set(HttpHeaders.ifRangeHeader, validator);
            }
          }
          response = await request.close().timeout(const Duration(seconds: 20));
          if (!response.isRedirect) break;
          final next = response.headers.value(HttpHeaders.locationHeader);
          if (next == null) throw StateError('Invalid update redirect.');
          location = location.resolve(next);
          await response.drain<void>();
        }
        if (response == null || response.isRedirect) {
          throw StateError('Too many update redirects.');
        }
        if (response.statusCode == 416) {
          // Do not trust a range error as evidence that local bytes are complete.
          throw StateError(
            'Server rejected the saved range. Discard this download and retry.',
          );
        }
        final etag = response.headers.value(HttpHeaders.etagHeader);
        final validator = etag != null && !etag.startsWith('W/')
            ? etag
            : response.headers.value(HttpHeaders.lastModifiedHeader);
        if (response.statusCode == 206) {
          final range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(
            response.headers.value(HttpHeaders.contentRangeHeader) ?? '',
          );
          if (range == null ||
              int.parse(range[1]!) != offset ||
              int.parse(range[2]!) != size - 1 ||
              int.parse(range[3]!) != size ||
              (stored['validator'] != null &&
                  validator != stored['validator'])) {
            throw StateError(
              'Remote asset changed or returned an invalid range. Discard and retry.',
            );
          }
        } else if (response.statusCode == 200) {
          if (offset > 0) {
            notice =
                'Server cannot resume this download; restarting from zero.';
            state?.call(notice!);
          }
          offset = 0; // Never append a full response to a partial file.
          await partial.writeAsBytes([], flush: true);
          progress(0, size);
        } else {
          throw HttpException(
            'Update download failed (HTTP ${response.statusCode}).',
          );
        }
        if (response.headers.value(HttpHeaders.contentEncodingHeader)
            case final String encoding when encoding != 'identity') {
          throw StateError('Unexpected update content encoding.');
        }
        if (response.contentLength >= 0 &&
            response.contentLength != size - offset) {
          throw StateError('Response length differs from the published asset.');
        }
        stored = {...key, 'validator': ?validator};
        await persist(stored);
        final output = await partial.open(mode: FileMode.append);
        var received = offset;
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 30),
          )) {
            if (_paused) throw const UpdateDownloadPaused();
            if (received + chunk.length > size) {
              throw StateError('Download exceeds published size.');
            }
            await output.writeFrom(chunk);
            received += chunk.length;
            progress(received, size);
            if (_paused) throw const UpdateDownloadPaused();
          }
          await output.flush();
        } finally {
          await output.close();
        }
        if (_paused) throw const UpdateDownloadPaused();
        if (received != size) {
          throw const HttpException(
            'Connection interrupted. Saved bytes retained; tap Resume.',
          );
        }
        verifying = true;
        progress(size, size);
        state?.call('Verifying download…');
      }
      if (!await valid(partial)) {
        await partial.delete();
        if (await metadata.exists()) await metadata.delete();
        throw StateError(
          'Package SHA-256 checksum failed. Discarded damaged bytes; download again.',
        );
      }
      if (await target.exists()) await target.delete();
      final complete = await partial.rename(target.path);
      if (await metadata.exists()) await metadata.delete();
      return complete;
    } catch (_) {
      if (_paused) throw const UpdateDownloadPaused();
      rethrow; // Transient failures retain bytes and their exact asset binding.
    } finally {
      client.close(force: true);
      _client = null;
    }
  }
}
