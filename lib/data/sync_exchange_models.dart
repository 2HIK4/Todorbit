import 'dart:typed_data';

class SyncBinding {
  const SyncBinding({
    required this.workspace,
    required this.account,
    required this.device,
  });
  final String workspace, account, device;
}

class SyncLease {
  const SyncLease({required this.binding, required this.owner});
  final SyncBinding binding;
  final String owner;
  static const duration = Duration(seconds: 30);
}

class PendingSyncBatch {
  PendingSyncBatch({
    required this.id,
    required this.binding,
    required Uint8List bytes,
    required this.sha256,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String id, sha256;
  final SyncBinding binding;
  final Uint8List bytes;
  Map<String, String> get properties => Map.unmodifiable({
    'kind': 'operations',
    'batchId': id,
    'workspaceId': binding.workspace,
    'deviceId': binding.device,
    'protocol': '1',
  });
}
