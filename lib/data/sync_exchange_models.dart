import 'dart:typed_data';

import '../domain/sync/causal_record.dart';

class SyncConflictRecord {
  const SyncConflictRecord({
    required this.entity,
    required this.key,
    required this.local,
    required this.review,
    required this.candidates,
  });
  final String entity, key;
  final Map<String, Object?>? local;
  final SyncRecordReview review;
  final Map<String, Map<String, Object?>?> candidates;
  String get id => '$entity:$key';
}

class SyncConflictReview {
  const SyncConflictReview({
    required this.token,
    required this.records,
    required this.reason,
  });
  final String token;
  final List<SyncConflictRecord> records;
  final String? reason;
}

class SyncResolutionChoice {
  const SyncResolutionChoice.local() : revision = null;
  const SyncResolutionChoice.revision(this.revision);
  final String? revision;
}

class SyncBinding {
  const SyncBinding({
    required this.workspace,
    required this.account,
    required this.device,
  });
  final String workspace, account, device;
}

class SyncExchangeStatus {
  const SyncExchangeStatus({
    required this.binding,
    required this.enabled,
    required this.automatic,
    required this.quarantined,
    required this.pending,
    required this.conflicts,
    required this.waiting,
    this.changeToken,
    this.lastSuccess,
    this.retryAt,
    this.errorCode,
  });
  final SyncBinding? binding;
  final bool enabled, automatic, quarantined;
  final int pending, conflicts, waiting;
  final String? changeToken, errorCode;
  final DateTime? lastSuccess, retryAt;
}

class SyncLease {
  const SyncLease({required this.binding, required this.owner});
  final SyncBinding binding;
  final String owner;
  static const duration = Duration(seconds: 30);
}

enum SyncApplyState { idle, waiting, retry, applied, needsReview }

class SyncApplyResult {
  const SyncApplyResult(
    this.state, {
    this.groupId,
    this.reason,
    this.records = 0,
  });
  final SyncApplyState state;
  final String? groupId, reason;
  final int records;
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
