import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'cloud_storage_provider.dart';
import 'google_drive_auth.dart';

class DriveChangePage {
  const DriveChangePage({
    required this.objects,
    required this.removedIds,
    required this.checkpoint,
    required this.hasMore,
  });
  final List<CloudObject> objects;
  final Set<String> removedIds;
  final String checkpoint;
  final bool hasMore;
}

class DriveCheckpointExpired extends CloudFailure {
  const DriveCheckpointExpired()
    : super(
        'Drive change history expired. Re-read retained cloud history before advancing the checkpoint. Local work is unchanged.',
      );
}

abstract interface class SyncStorageProvider implements CloudStorageProvider {
  Future<List<CloudObject>> listWorkspaceProofs();
  Future<String> startChangeToken();
  Future<DriveChangePage> changes(String token);
}

class GoogleDriveProvider implements CloudStorageProvider, SyncStorageProvider {
  GoogleDriveProvider(this.auth, this.client)
    : _namespace = 'todorbit',
      _idProperty = 'backupId',
      _extension = 'tdbackup';
  GoogleDriveProvider.sync(this.auth, this.client)
    : _namespace = 'todorbit-sync',
      _idProperty = 'batchId',
      _extension = 'tdsync';
  final GoogleDriveAuth auth;
  final http.Client client;
  final String _namespace, _idProperty, _extension;
  static const maxBytes = 128 * 1024 * 1024;
  static const _fields =
      'id,name,size,createdTime,md5Checksum,appProperties,spaces';
  @override
  CloudAccount? get account => auth.account;

  Future<http.StreamedResponse> _send(http.Request Function() request) async {
    final accountId = account?.id;
    if (accountId == null) {
      throw const CloudFailure('Connect Google Drive first.');
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      final current = request();
      current.followRedirects = false;
      final token = await auth.accessToken(forceRefresh: attempt == 1);
      _checkAccount(accountId);
      current.headers['Authorization'] = 'Bearer $token';
      final response = await client
          .send(current)
          .timeout(const Duration(seconds: 60));
      if (account?.id != accountId) {
        await response.stream.drain<void>();
        _checkAccount(accountId);
      }
      if (response.statusCode != 401 || attempt == 1) return response;
      await response.stream.drain<void>();
    }
    throw const CloudFailure('Google session expired. Reconnect.');
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    List<int>? body,
    Set<int> accepted = const {200},
  }) async {
    final accountId = account?.id;
    if (accountId == null) {
      throw const CloudFailure('Connect Google Drive first.');
    }
    final stream = await _send(() {
      final request = http.Request(method, uri);
      if (headers != null) request.headers.addAll(headers);
      if (body != null) request.bodyBytes = body;
      return request;
    });
    final response = await http.Response.fromStream(stream)
        .timeout(const Duration(seconds: 60));
    _checkAccount(accountId);
    if (!accepted.contains(response.statusCode)) _fail(response.statusCode);
    return response;
  }

  Never _fail(int status) => throw CloudFailure(switch (status) {
    401 => 'Google session expired or was revoked. Reconnect Google Drive.',
    403 =>
      'Google Drive denied access. Check backup permission and storage quota.',
    404 => 'This cloud backup is no longer available.',
    429 => 'Google Drive is busy. Try again later.',
    >= 500 => 'Google Drive is temporarily unavailable. Try again later.',
    _ => 'Google Drive request failed (HTTP $status).',
  });

  void _checkAccount(String id) {
    if (account?.id != id) {
      throw const CloudFailure(
        'Google account changed. Reload the backup list.',
      );
    }
  }

  CloudObject _object(Map<String, dynamic> data, String accountId) {
    final properties =
        (data['appProperties'] as Map?)?.cast<String, String>() ?? {};
    final bytes = int.tryParse('${data['size']}') ?? -1;
    if (data['id'] is! String ||
        data['name'] is! String ||
        bytes < 1 ||
        bytes > maxBytes ||
        properties['application'] != _namespace ||
        !(data['spaces'] as List? ?? []).contains('appDataFolder') ||
        data['md5Checksum'] is! String) {
      throw const CloudFailure(
        'Invalid or unsupported Google Drive backup metadata.',
      );
    }
    return CloudObject(
      id: data['id'] as String,
      accountId: accountId,
      name: data['name'] as String,
      bytes: bytes,
      createdAt: DateTime.parse(data['createdTime'] as String).toUtc(),
      properties: properties,
      md5: data['md5Checksum'] as String,
    );
  }

  @override
  Future<List<CloudObject>> list() => _list();

  @override
  Future<List<CloudObject>> listWorkspaceProofs() => _list(kind: 'workspace');

  Future<List<CloudObject>> _list({String? kind}) async {
    final accountId = account?.id;
    if (accountId == null) {
      throw const CloudFailure('Connect Google Drive first.');
    }
    final result = <CloudObject>[];
    String? page;
    final seen = <String>{};
    do {
      final response = await _request(
        'GET',
        Uri.https('www.googleapis.com', '/drive/v3/files', {
          'spaces': 'appDataFolder',
          'q':
              "trashed = false and appProperties has { key='application' and value='$_namespace' }${kind == null ? '' : " and appProperties has { key='kind' and value='$kind' }"}",
          'fields': 'nextPageToken,files($_fields)',
          'pageSize': '100',
          'orderBy': 'createdTime desc',
          'pageToken': ?page,
        }),
      );
      _checkAccount(accountId);
      final data = jsonDecode(response.body) as Map;
      for (final item in data['files'] as List) {
        result.add(_object((item as Map).cast<String, dynamic>(), accountId));
      }
      page = data['nextPageToken'] as String?;
      if (page != null && !seen.add(page)) {
        throw const CloudFailure('Google Drive returned a repeated page.');
      }
    } while (page != null);
    return result;
  }

  @override
  Future<String> startChangeToken() async {
    final accountId = account?.id;
    if (accountId == null) {
      throw const CloudFailure('Connect Google Drive first.');
    }
    final response = await _request(
      'GET',
      Uri.https('www.googleapis.com', '/drive/v3/changes/startPageToken'),
    );
    _checkAccount(accountId);
    final data = jsonDecode(response.body) as Map;
    final token = data['startPageToken'];
    if (token is! String || token.isEmpty || token.length > 4096) {
      throw const CloudFailure(
        'Google Drive returned an invalid change checkpoint.',
      );
    }
    return token;
  }

  // The store commits this page's checkpoint only with its retained/applied
  // operations. Removed cloud objects are never interpreted as record deletes.
  @override
  Future<DriveChangePage> changes(String token) async {
    if (token.isEmpty || token.length > 4096) {
      throw const CloudFailure('Invalid change checkpoint.');
    }
    final accountId = account?.id;
    if (accountId == null) {
      throw const CloudFailure('Connect Google Drive first.');
    }
    final response = await _request(
      'GET',
      Uri.https('www.googleapis.com', '/drive/v3/changes', {
        'pageToken': token,
        'spaces': 'appDataFolder',
        'pageSize': '100',
        'includeRemoved': 'true',
        'fields':
            'nextPageToken,newStartPageToken,changes(fileId,removed,file($_fields,trashed))',
      }),
      accepted: const {200, 410},
    );
    if (response.statusCode == 410) {
      throw const DriveCheckpointExpired();
    }
    _checkAccount(accountId);
    final data = jsonDecode(response.body) as Map;
    final next = data['nextPageToken'];
    final checkpoint = next ?? data['newStartPageToken'];
    if (checkpoint is! String ||
        checkpoint.isEmpty ||
        checkpoint.length > 4096 ||
        (next != null && data['newStartPageToken'] != null) ||
        data['changes'] is! List ||
        (data['changes'] as List).length > 100 ||
        (next != null && next == token)) {
      throw const CloudFailure('Google Drive returned an invalid change page.');
    }
    final objects = <CloudObject>[];
    final removed = <String>{};
    for (final change in data['changes'] as List) {
      if (change is! Map || change['fileId'] is! String) {
        throw const CloudFailure('Invalid Drive change.');
      }
      if (change['removed'] == true ||
          (change['file'] is Map &&
              (change['file'] as Map)['trashed'] == true)) {
        removed.add(change['fileId'] as String);
        continue;
      }
      final file = change['file'];
      if (file is Map &&
          (file['appProperties'] as Map?)?['application'] == _namespace) {
        if (file['id'] != change['fileId']) {
          throw const CloudFailure(
            'Drive change identity differs from its file.',
          );
        }
        objects.add(_object(file.cast<String, dynamic>(), accountId));
      }
    }
    return DriveChangePage(
      objects: List.unmodifiable(objects),
      removedIds: Set.unmodifiable(removed),
      checkpoint: checkpoint,
      hasMore: next != null,
    );
  }

  Future<CloudObject> _inspect(String id, String accountId) async {
    _checkAccount(accountId);
    final response = await _request(
      'GET',
      Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/${Uri.encodeComponent(id)}',
        {'fields': _fields},
      ),
    );
    _checkAccount(accountId);
    return _object(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
      accountId,
    );
  }

  @override
  Future<CloudObject> upload(
    Uint8List bytes,
    Map<String, String> properties,
    CloudProgress progress,
  ) async {
    final accountId = account?.id;
    if (accountId == null) {
      throw const CloudFailure('Connect Google Drive first.');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const CloudFailure('Backup exceeds the 128 MiB cloud limit.');
    }
    final name =
        'todorbit-${properties['kind']}-${properties[_idProperty]}.$_extension';
    final start = await _request(
      'POST',
      Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
        'uploadType': 'resumable',
        'fields': 'id',
      }),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': 'application/octet-stream',
        'X-Upload-Content-Length': '${bytes.length}',
      },
      body: utf8.encode(
        jsonEncode({
          'name': name,
          'parents': ['appDataFolder'],
          'appProperties': {...properties, 'application': _namespace},
        }),
      ),
    );
    final location = Uri.tryParse(start.headers['location'] ?? '');
    if (location == null ||
        location.scheme != 'https' ||
        location.host != 'www.googleapis.com' ||
        !location.path.startsWith('/upload/drive/v3/files') ||
        location.userInfo.isNotEmpty ||
        (location.hasPort && location.port != 443)) {
      throw const CloudFailure(
        'Google Drive returned an invalid upload session.',
      );
    }
    const chunkSize = 1024 * 1024;
    String? id;
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      _checkAccount(accountId);
      final end = (offset + chunkSize).clamp(0, bytes.length);
      final response = await _request(
        'PUT',
        location,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Range': 'bytes $offset-${end - 1}/${bytes.length}',
        },
        body: bytes.sublist(offset, end),
        accepted: const {200, 201, 308},
      );
      if (end < bytes.length) {
        if (response.statusCode != 308 ||
            response.headers['range'] != 'bytes=0-${end - 1}') {
          throw const CloudFailure(
            'Google Drive did not confirm the uploaded chunk. Retry the backup.',
          );
        }
      } else {
        if (response.statusCode == 308) {
          throw const CloudFailure('Google Drive did not complete the upload.');
        }
        id = (jsonDecode(response.body) as Map)['id'] as String?;
      }
      progress('Uploading encrypted backup', end, bytes.length);
    }
    if (id == null) {
      throw const CloudFailure('Google Drive did not confirm the backup.');
    }
    progress('Verifying stored backup', bytes.length, bytes.length);
    final stored = await _inspect(id, accountId);
    if (stored.bytes != bytes.length ||
        stored.md5 != md5.convert(bytes).toString() ||
        stored.properties[_idProperty] != properties[_idProperty]) {
      throw const CloudFailure(
        'Stored backup verification failed. Existing snapshots are unchanged.',
      );
    }
    // Read back and SHA-256 check before reporting success, even where Drive
    // does not expose a SHA-256 checksum for a binary object.
    final downloaded = await download(
      stored,
      (stage, done, total) => progress('Verifying remote content', done, total),
    );
    if (sha256.convert(downloaded) != sha256.convert(bytes)) {
      throw const CloudFailure(
        'Stored backup content did not match the upload.',
      );
    }
    await _request(
      'PATCH',
      Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/${Uri.encodeComponent(id)}',
      ),
      headers: {'Content-Type': 'application/json'},
      body: utf8.encode(
        jsonEncode({
          'appProperties': {...stored.properties, 'verified': 'true'},
        }),
      ),
    );
    final verified = await _inspect(id, accountId);
    if (verified.properties['verified'] != 'true' ||
        verified.md5 != stored.md5 ||
        verified.bytes != stored.bytes) {
      throw const CloudFailure(
        'Google Drive could not confirm the verified backup metadata.',
      );
    }
    return verified;
  }

  @override
  Future<Uint8List> download(CloudObject object, CloudProgress progress) async {
    _checkAccount(object.accountId);
    final checked = await _inspect(object.id, object.accountId);
    if (checked.bytes != object.bytes ||
        checked.md5 != object.md5 ||
        checked.properties[_idProperty] != object.properties[_idProperty]) {
      throw const CloudFailure('Cloud backup changed. Reload the list.');
    }
    final response = await _send(
      () => http.Request(
        'GET',
        Uri.https(
          'www.googleapis.com',
          '/drive/v3/files/${Uri.encodeComponent(object.id)}',
          {'alt': 'media'},
        ),
      ),
    );
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      _fail(response.statusCode);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 60),
    )) {
      _checkAccount(object.accountId);
      builder.add(chunk);
      if (builder.length > object.bytes || builder.length > maxBytes) {
        throw const CloudFailure('Cloud backup exceeded its declared size.');
      }
      progress('Downloading encrypted backup', builder.length, object.bytes);
    }
    final bytes = builder.takeBytes();
    if (bytes.length != object.bytes ||
        md5.convert(bytes).toString() != object.md5) {
      throw const CloudFailure(
        'Cloud backup download is incomplete or corrupted.',
      );
    }
    return bytes;
  }

  @override
  Future<void> delete(CloudObject object) async {
    _checkAccount(object.accountId);
    await _inspect(object.id, object.accountId);
    await _request(
      'DELETE',
      Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/${Uri.encodeComponent(object.id)}',
      ),
      accepted: const {204},
    );
  }
}
