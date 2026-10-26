import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:math' as math;

import '../../data/backup_service.dart';
import '../../data/app_database.dart';
import 'windows_database_file_dialog.dart';

class BackupDialog extends StatefulWidget {
  const BackupDialog({
    super.key,
    required this.service,
    this.automaticError,
    this.chooseImport,
    this.chooseExport,
    this.embedded = false,
  });
  final BackupService service;
  final String? automaticError;
  final Future<File?> Function()? chooseImport;
  final Future<File?> Function()? chooseExport;
  final bool embedded;

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  List<BackupRecord>? records;
  String? pendingName;
  String? restoreResult;
  String? error;
  String? success;
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
      final result = await widget.service.restoreStatus();
      if (mounted) {
        setState(() {
          records = loaded;
          pendingName = pending;
          restoreResult = result;
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
      if (mounted) setState(() => success = 'Backup created and verified.');
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _export() async {
    setState(() {
      busy = true;
      error = null;
      success = null;
    });
    try {
      final destination =
          await (widget.chooseExport ??
              const WindowsDatabaseFileDialog().chooseExport)();
      if (destination == null || !mounted) return;
      final exported = await widget.service.exportTo(destination);
      if (mounted) {
        setState(
          () => success =
              'Exported a verified SQLite snapshot to ${exported.path}',
        );
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      busy = true;
      error = null;
      success = null;
    });
    try {
      final source =
          await (widget.chooseImport ??
              const WindowsDatabaseFileDialog().chooseImport)();
      if (source == null || !mounted) return;
      final imported = await widget.service.importSnapshot(
        source,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      if (!mounted) return;
      setState(() {
        success = 'Staged a verified snapshot from ${source.path}';
      });
      await _reload();
      if (mounted) await _schedule(imported, importedFrom: source.path);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _schedule(BackupRecord record, {String? importedFrom}) async {
    BackupSummary summary;
    try {
      summary = await widget.service.summarize(record);
    } catch (failure) {
      if (mounted) setState(() => error = 'Could not preview backup: $failure');
      return;
    }
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace current data on next launch?'),
        content: Text(
          '${importedFrom == null ? 'Stored backup' : 'Imported backup'} from ${_date(dialogContext, record.createdAt)}.\n\n'
          '${summary.description.isEmpty ? 'No records in this backup' : summary.description}.\n\n'
          'When you next start Todorbit, this backup replaces your current tasks, events, and other database records. It does not merge them. Todorbit first saves your current database as a Before Restore backup so you can recover it.\n\n'
          'Changes made since this backup will no longer appear in the active database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm replacement'),
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
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: 700,
      height: widget.embedded
          ? 720
          : math.min(
              MediaQuery.sizeOf(context).height * 0.85,
              records != null && records!.length < 3 && pendingName == null
                  ? 480.0
                  : 620.0,
            ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Backup & Restore',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (!widget.embedded)
                  IconButton(
                    tooltip: 'Close backups',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const Text(
              'Backups include your tasks, events, and other database records.',
            ),
            const SizedBox(height: 16),
            Text(
              'Create or export',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : _create,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(busy ? 'Creating…' : 'Create backup now'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : _export,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Export SQLite'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Import or restore',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Restoring replaces the current database after you close and reopen Todorbit.',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: busy || pendingName != null ? null : _import,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Import SQLite'),
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
            if (success != null) SelectableText(success!),
            if (pendingName == null && restoreResult != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(restoreResult!),
                ),
              ),
            if (pendingName != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending restore',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Close Todorbit and its widget, then reopen Todorbit to apply the backup. Your current database will first be saved as a Before Restore backup. This restore has not happened yet.',
                      ),
                      TextButton(
                        onPressed: busy ? null : _cancelRestore,
                        child: const Text('Cancel scheduled restore'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Backup history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            records == null
                ? const Center(child: CircularProgressIndicator())
                : records!.isEmpty
                ? const Center(child: Text('No backups yet.'))
                : ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final record in records!) ...[
                        ListTile(
                          dense: true,
                          leading: Icon(
                            record.schemaVersion < 0
                                ? Icons.warning_amber_outlined
                                : Icons.storage_outlined,
                          ),
                          title: Text(
                            '${_kind(record.kind)} · ${_date(context, record.createdAt)}',
                          ),
                          subtitle: Text(
                            record.schemaVersion < 0
                                ? 'Integrity check failed'
                                : '${_size(record.bytes)} · ${record.schemaVersion > AppDatabase.currentSchemaVersion ? 'Newer version, cannot restore' : 'Ready to restore'}',
                          ),
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
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 48,
                            right: 8,
                            bottom: 4,
                          ),
                          child: ExpansionTile(
                            title: const Text('Details'),
                            tilePadding: EdgeInsets.zero,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SelectableText(
                                  'Schema ${record.schemaVersion}\n${record.file.path}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
    return widget.embedded ? content : Dialog(child: content);
  }
}

String _date(BuildContext context, DateTime instant) {
  final local = instant.toLocal();
  final format = MaterialLocalizations.of(context);
  return '${format.formatMediumDate(local)} ${format.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
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
