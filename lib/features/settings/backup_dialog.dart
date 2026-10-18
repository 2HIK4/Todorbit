import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/backup_service.dart';
import '../../data/app_database.dart';

class BackupDialog extends StatefulWidget {
  const BackupDialog({super.key, required this.service, this.automaticError});
  final BackupService service;
  final String? automaticError;

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  List<BackupRecord>? records;
  String? pendingName;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final loaded = await widget.service.list();
      final pending = await widget.service.pendingRestoreName();
      if (mounted) {
        setState(() {
          records = loaded;
          pendingName = pending;
          error = null;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    }
  }

  Future<void> _create() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service.createBackup(BackupKind.manual);
      await _reload();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _schedule(BackupRecord record) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this snapshot on next launch?'),
        content: Text(
          'Life Manager will replace its current database with '
          '${record.file.uri.pathSegments.last} when it next starts. '
          'Current data will first be saved in a separate Before restore backup. '
          'Changes made after this snapshot will no longer appear in the active database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Schedule restore'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service.scheduleRestore(
        record,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await _reload();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancelRestore() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service.cancelScheduledRestore();
      await _reload();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 620,
      height: 560,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Database backups',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close backups',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Automatic snapshots are taken daily and before a schema upgrade. The newest 14 daily copies are retained; manual and pre-upgrade copies are kept.',
            ),
            const SizedBox(height: 8),
            SelectableText(widget.service.backupDirectory.path),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: widget.service.backupDirectory.path),
                ),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy backup folder path'),
              ),
            ),
            if (widget.automaticError != null)
              Text(
                'Automatic backup failed: ${widget.automaticError}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (pendingName != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Restore scheduled: $pendingName'),
                      const Text(
                        'Close and reopen Life Manager to apply it. The current database will be backed up first.',
                      ),
                      TextButton(
                        onPressed: busy ? null : _cancelRestore,
                        child: const Text('Cancel scheduled restore'),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Stored snapshots',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : _create,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(busy ? 'Creating…' : 'Create backup now'),
                ),
              ],
            ),
            Expanded(
              child: records == null
                  ? const Center(child: CircularProgressIndicator())
                  : records!.isEmpty
                  ? const Center(child: Text('No backups yet.'))
                  : ListView(
                      children: [
                        for (final record in records!)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              record.schemaVersion < 0
                                  ? Icons.warning_amber_outlined
                                  : Icons.storage_outlined,
                            ),
                            title: Text(_kind(record.kind)),
                            subtitle: Text(
                              '${record.file.uri.pathSegments.last}\n'
                              '${_size(record.bytes)} · ${record.schemaVersion < 0 ? 'Integrity check failed' : 'Schema ${record.schemaVersion}'}',
                            ),
                            isThreeLine: true,
                            trailing:
                                record.schemaVersion < 1 ||
                                    record.schemaVersion >
                                        AppDatabase.currentSchemaVersion ||
                                    pendingName != null ||
                                    busy
                                ? null
                                : TextButton(
                                    onPressed: () => _schedule(record),
                                    child: const Text('Restore'),
                                  ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _kind(BackupKind kind) => switch (kind) {
  BackupKind.automatic => 'Automatic',
  BackupKind.beforeUpgrade => 'Before upgrade',
  BackupKind.beforeRestore => 'Before restore',
  BackupKind.manual => 'Manual',
};

String _size(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(0)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
