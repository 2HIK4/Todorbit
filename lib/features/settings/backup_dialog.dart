import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/backup_service.dart';

class BackupDialog extends StatefulWidget {
  const BackupDialog({super.key, required this.service, this.automaticError});
  final BackupService service;
  final String? automaticError;

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  List<BackupRecord>? records;
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
      if (mounted) {
        setState(() {
          records = loaded;
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
  BackupKind.manual => 'Manual',
};

String _size(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(0)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
