import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'cloud_storage_provider.dart';

/// Append-only generation graph. Heads contain no planner content or keys and
/// are deliberately retained after cleanup. Concurrent tips never choose a winner.
class SyncGeneration {
  const SyncGeneration(this.heads, this.tips);
  final Map<String, Map<String, dynamic>> heads;
  final Set<String> tips;
  String? get active {
    if (tips.length > 1)
      throw const CloudFailure(
        'Concurrent sync replacements',
        kind: CloudFailureKind.conflict,
      );
    return tips.firstOrNull;
  }

  static const format = 'todorbit-sync-generation:1';

  static Future<SyncGeneration> read(
    CloudStorageProvider storage,
    String account,
    List<CloudObject> objects,
  ) async {
    final heads = <String, Map<String, dynamic>>{};
    final files = objects.where((o) => o.properties['kind'] == 'head').toList();
    if (files.length > 256)
      throw const CloudFailure(
        'Generation history limit',
        kind: CloudFailureKind.incompatible,
      );
    for (final file in files) {
      if (file.accountId != account ||
          file.properties['application'] != 'todorbit-sync' ||
          file.properties['protocol'] != '3' ||
          file.bytes > 16384)
        throw const FormatException('Invalid generation identity');
      final bytes = await storage.download(file, (_, _, _) {});
      if (storage.account?.id != account)
        throw const CloudFailure(
          'Account changed',
          kind: CloudFailureKind.account,
        );
      final value = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final workspace = value['workspace'];
      if (value['format'] != format)
        throw const CloudFailure(
          'Unsupported generation',
          kind: CloudFailureKind.incompatible,
        );
      if (value.length != 6 ||
          value['account'] != account ||
          workspace is! String ||
          !Uuid.isValidUUID(fromString: workspace) ||
          file.properties['workspaceId'] != workspace ||
          value['parents'] is! List ||
          (value['parents'] as List).length > 128 ||
          (value['parents'] as List).any(
            (p) => p is! String || !Uuid.isValidUUID(fromString: p),
          ) ||
          value['batches'] is! int ||
          (value['batches'] as int) < 0 ||
          value['digest'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['digest'] as String))
        throw const FormatException('Invalid generation record');
      if (heads.containsKey(workspace) &&
          jsonEncode(heads[workspace]) != jsonEncode(value))
        throw const FormatException('Conflicting generation records');
      heads[workspace] = value;
    }
    final visited = <String>{}, visiting = <String>{};
    void visit(String id) {
      if (visiting.contains(id))
        throw const FormatException('Cyclic generation history');
      if (visited.contains(id)) return;
      final value = heads[id];
      if (value == null)
        throw const FormatException('Missing generation history');
      visiting.add(id);
      for (final parent in (value['parents'] as List).cast<String>()) {
        visit(parent);
      }
      visiting.remove(id);
      visited.add(id);
    }

    for (final id in heads.keys) {
      visit(id);
    }
    final parents = heads.values
        .expand((v) => (v['parents'] as List).cast<String>())
        .toSet();
    return SyncGeneration(
      heads,
      heads.keys.where((id) => !parents.contains(id)).toSet(),
    );
  }

  static Uint8List encode({
    required String account,
    required String workspace,
    required List<String> parents,
    required int batches,
    required String digest,
  }) => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': format,
        'account': account,
        'workspace': workspace,
        'parents': parents,
        'batches': batches,
        'digest': digest,
      }),
    ),
  );
}
