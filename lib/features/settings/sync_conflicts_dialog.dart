import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/sync_controller.dart';
import '../../data/sync_exchange_models.dart';
import '../shared/status_notice.dart';
import '../shared/dialog_action_bar.dart';

Future<void> showSyncConflicts(
  BuildContext context,
  SyncController controller, {
  bool automatic = false,
}) async {
  if (!controller.isUnlocked()) return;
  final review = await controller.reviewConflicts();
  if (!context.mounted ||
      review == null ||
      !controller.isUnlocked() ||
      (automatic && review.dismissed)) {
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SyncConflictsDialog(controller: controller, review: review),
  );
}

class SyncConflictsDialog extends StatefulWidget {
  const SyncConflictsDialog({
    super.key,
    required this.controller,
    required this.review,
  });
  final SyncController controller;
  final SyncConflictReview review;
  @override
  State<SyncConflictsDialog> createState() => _SyncConflictsDialogState();
}

class _SyncConflictsDialogState extends State<SyncConflictsDialog> {
  late SyncConflictReview review = widget.review;
  final choices = <String, SyncResolutionChoice>{};
  bool applying = false, handled = false, confirming = false;
  String? error;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_privacy);
  }

  void _privacy() {
    if (!widget.controller.isUnlocked() && mounted) {
      handled = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_privacy);
    super.dispose();
  }

  String _value(Object? value, {String? field}) => switch ((field, value)) {
    ('priority', 0) => 'None',
    ('priority', 1) => 'Low',
    ('priority', 2) => 'Medium',
    ('priority', 3) => 'High',
    (_, null) => 'Not set',
    (_, String text) => text.isEmpty ? 'Empty' : text,
    (_, bool flag) => flag ? 'Yes' : 'No',
    _ => const JsonEncoder.withIndent('  ').convert(value),
  };

  void _choose(String id, SyncResolutionChoice choice) => setState(() {
    choices[id] = choice;
    confirming = false;
  });

  Widget _version(
    SyncConflictRecord record,
    String title,
    Map<String, Object?>? value,
    bool selected,
    VoidCallback select,
  ) {
    final theme = Theme.of(context);
    final fields = record.review.conflicts.map((c) => c.field).toSet();
    final wholeRecord = fields.contains(r'$record') || fields.isEmpty;
    final visibleFields = wholeRecord
        ? (value?.keys
                  .where(
                    (key) => !{'id', 'modified_at', 'created_at'}.contains(key),
                  )
                  .toList() ??
              <String>[])
        : fields.toList();
    return Semantics(
      container: true,
      selected: selected,
      child: Card(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              if (value == null)
                const Text('Deleted / not present')
              else
                for (final field in visibleFields) ...[
                  Text(
                    field.replaceAll('_', ' '),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _value(value[field], field: field),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                ],
              OutlinedButton.icon(
                onPressed: applying ? null : select,
                icon: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                ),
                label: Text(
                  value == null
                      ? 'Keep deletion'
                      : record.local == null ||
                            record.candidates.values.any((v) => v == null)
                      ? 'Restore this record'
                      : title.startsWith('This')
                      ? 'Keep this device'
                      : 'Keep cloud version',
                ),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Complete record'),
                children: [
                  SelectableText(
                    value == null
                        ? 'Deleted / not present'
                        : const JsonEncoder.withIndent('  ').convert(value),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _record(SyncConflictRecord record) {
    final theme = Theme.of(context);
    final cloud = record.candidates.values
        .whereType<Map<String, Object?>>()
        .firstOrNull;
    final title =
        record.local?['title'] ??
        record.local?['name'] ??
        cloud?['title'] ??
        cloud?['name'] ??
        record.key;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            record.entity.replaceAll('_', ' '),
            style: theme.textTheme.bodySmall,
          ),
          Semantics(
            header: true,
            child: Text('$title', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          Text(
            record.review.needsDecision
                ? 'Changed: ${record.review.conflicts.map((c) => c.field == r'$record' ? 'record / deletion' : c.field.replaceAll('_', ' ')).join(', ')}'
                : 'Related record. Compatible changes are preserved unless a whole-record decision is needed.',
            style: theme.textTheme.bodySmall,
          ),
          if (record.consequence)
            const StatusNotice(
              title: 'Related change',
              message: 'This record is affected by the cloud action. Review its outcome before applying.',
              icon: Icons.account_tree_outlined,
            ),
          if (record.review.conflicts.any((c) => c.field == r'$record'))
            const StatusNotice(
              title: 'Whole-record decision',
              message: 'This choice may delete or replace the record. Review both complete records.',
              icon: Icons.warning_amber_outlined,
            ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final versions = <Widget>[
                _version(
                  record,
                  'This Device',
                  record.local,
                  choices.containsKey(record.id) &&
                      choices[record.id]!.revision == null,
                  () => _choose(record.id, const SyncResolutionChoice.local()),
                ),
                for (final id in record.remoteHeads)
                  _version(
                    record,
                    record.consequence
                        ? 'If the cloud action is applied'
                        : record.remoteHeads.length == 1
                        ? 'Cloud'
                        : 'Cloud ${id.substring(0, math.min(8, id.length))}',
                    record.candidates[id],
                    choices[record.id]?.revision == id,
                    () => _choose(record.id, SyncResolutionChoice.revision(id)),
                  ),
              ];
              if (constraints.maxWidth < 720 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: versions,
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: versions.first),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: versions.skip(1).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
          if (record.review.conflicts.isNotEmpty)
            ExpansionTile(
              title: const Text('Previous / base values'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _value({
                      for (final conflict in record.review.conflicts)
                        conflict.field: conflict.base,
                    }),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _apply() async {
    setState(() => applying = true);
    try {
      final result = await widget.controller.resolve(review, choices);
      if (!mounted) return;
      if (result?.state == SyncApplyState.applied) {
        handled = true;
        Navigator.of(context).pop();
        return;
      }
      final updated = await widget.controller.reviewConflicts();
      if (!mounted) return;
      setState(() {
        if (updated != null) review = updated;
        choices.clear();
        error =
            widget.controller.message ?? 'Refresh the review and choose again.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'The decision was not applied. All competing versions are retained.',
        );
      }
    } finally {
      if (mounted) setState(() => applying = false);
    }
  }

  Future<void> _later() async {
    try {
      await widget.controller.dismiss(review);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'The review could not be dismissed. Its versions are retained.',
        );
      }
      return;
    }
    if (mounted) {
      handled = true;
      Navigator.of(context).pop();
    }
  }

  Widget _header(bool canBulkCloud) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Choose the values to keep. Both versions are retained until you apply. Compatible changes are preserved.',
      ),
      if (review.structural)
        const StatusNotice(
          title: 'Review related records',
          message: 'These decisions affect linked records or recurrence. Review the complete group before applying.',
          icon: Icons.account_tree_outlined,
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (review.reason != null)
        const Text(
          'Local state requires recovery before these decisions can be applied.',
        ),
      if (!canBulkCloud)
        const Text(
          'Some records have multiple cloud versions or no safe cloud outcome. Review each available version; a bulk cloud choice is unavailable.',
        ),
      const SizedBox(height: 8),
      Text(
        'Select all (review before applying)',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: applying
                ? null
                : () => setState(() {
                    confirming = false;
                    for (final record in review.records) {
                      choices[record.id] = const SyncResolutionChoice.local();
                    }
                  }),
            child: Text('Keep this device for all (${review.records.length})'),
          ),
          TextButton(
            onPressed: applying || !canBulkCloud
                ? null
                : () => setState(() {
                    confirming = false;
                    for (final record in review.records) {
                      choices[record.id] = SyncResolutionChoice.revision(
                        record.remoteHeads.single,
                      );
                    }
                  }),
            child: Text('Keep cloud for all (${review.records.length})'),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final canBulkCloud = review.records.every((r) => r.remoteHeads.length == 1);
    final compactReview =
        screen.width >= 800 &&
        review.records.length == 1 &&
        MediaQuery.textScalerOf(context).scale(14) <= 18.2;
    final scrollingTitle =
        screen.height < 500 || MediaQuery.textScalerOf(context).scale(14) > 21;
    final title = Semantics(
      header: true,
      child: Text(
        'Resolve sync conflicts',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
    final requiredRecords = review.records.where(
      (r) => review.structural || r.review.needsDecision,
    );
    final ready = requiredRecords.every((r) => choices.containsKey(r.id));
    final deletions = review.records.where((r) {
      final choice = choices[r.id];
      return choice != null &&
          (choice.revision == null ? r.local : r.candidates[choice.revision]) ==
              null;
    }).length;
    return PopScope(
      canPop: !applying,
      onPopInvokedWithResult: (popped, _) {
        if (popped && !handled && widget.controller.isUnlocked()) {
          widget.controller.dismiss(review).catchError((Object _) {});
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: math.min(1050, screen.width - 32),
          height: math.min(compactReview ? 640 : 850, screen.height - 48),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!scrollingTitle) ...[title, const SizedBox(height: 8)],
                Expanded(
                  child: confirming
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (scrollingTitle) ...[
                                title,
                                const SizedBox(height: 12),
                              ],
                              Text(
                                'Apply ${choices.length} decisions?',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'The chosen values will replace competing changes on your synced devices.${deletions > 0 ? ' $deletions records will be deleted.' : ''} Your separate backups are kept.',
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: review.records.length + 1,
                          itemBuilder: (_, i) => i == 0
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (scrollingTitle) ...[
                                      title,
                                      const SizedBox(height: 12),
                                    ],
                                    _header(canBulkCloud),
                                  ],
                                )
                              : _record(review.records[i - 1]),
                        ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${choices.length} of ${review.records.length} records selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                DialogActionBar(
                  children: [
                    TextButton(
                      onPressed: applying
                          ? null
                          : confirming
                          ? () => setState(() => confirming = false)
                          : _later,
                      child: Text(confirming ? 'Back' : 'Resolve later'),
                    ),
                    FilledButton(
                      onPressed:
                          applying ||
                              choices.isEmpty ||
                              !ready ||
                              review.reason != null
                          ? null
                          : confirming
                          ? _apply
                          : () => setState(() => confirming = true),
                      child: Text(
                        applying
                            ? 'Saving decisions…'
                            : confirming
                            ? 'Apply decisions'
                            : 'Apply selected resolutions',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
