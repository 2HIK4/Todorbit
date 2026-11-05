import '../shared/disclosure_tile.dart';
import '../shared/app_motion.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/sync_controller.dart';
import '../../data/sync_exchange_models.dart';
import '../shared/status_notice.dart';
import '../shared/dialog_action_bar.dart';
import '../shared/scroll_edge_fade.dart';

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
    animationStyle: AppMotion.style(context),
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
  bool loadingDraft = true;
  List<SyncConflictRecord> get decisionRecords => review.records
      .where(
        (r) => review.structural || r.review.needsDecision || r.consequence,
      )
      .toList();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_privacy);
    unawaited(_loadDraft());
  }

  Future<void> _loadDraft() async {
    try {
      final saved = await widget.controller.loadDecisionDraft(review);
      if (mounted) setState(() => choices.addAll(saved));
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Saved selections could not be read. Review each choice again.',
        );
      }
    } finally {
      if (mounted) setState(() => loadingDraft = false);
    }
  }

  void _saveDraft() {
    unawaited(
      widget.controller.saveDecisionDraft(review, Map.of(choices)).catchError((
        Object _,
      ) {
        if (mounted) {
          setState(
            () => error = 'Selections could not be saved for later. Keep this review open or choose again next time.',
          );
        }
      }),
    );
  }

  bool _deleted(Map<String, Object?>? value) =>
      value == null || value['deleted_at'] != null;

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

  String _fieldLabel(String field) =>
      const {
        'scheduled_date': 'Planned day',
        'deadline_date': 'Deadline',
        'starts_at': 'Starts',
        'ends_at': 'Ends',
        'deleted_at': 'Deleted',
        'updated_at': 'Last modified',
        'category_id': 'Category',
        'project_id': 'Project',
        'group_id': 'Checklist',
        'recurrence_series_id': 'Recurring series',
      }[field] ??
      field.replaceAll('_', ' ');

  String _entityLabel(String entity) =>
      const {
        'tasks': 'Task',
        'fixed_events': 'Event',
        'goals': 'Goal',
        'habits': 'Habit',
        'categories': 'Category',
        'projects': 'Project',
        'task_checklist': 'Checklist item',
        'task_checklist_groups': 'Checklist',
        'task_parents': 'Subtask relationship',
        'task_resources': 'Resource',
        'recurrence_series': 'Recurring task',
        'deletion_tombstones': 'Deletion record',
      }[entity] ??
      'Related item';

  void _choose(String id, SyncResolutionChoice choice) {
    setState(() {
      choices[id] = choice;
      confirming = false;
    });
    _saveDraft();
  }

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
              if (value?['updated_at'] != null)
                Text(
                  'Modified: ${value!['updated_at']}',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              if (value == null)
                const Text('Deleted / not present')
              else
                for (final field in visibleFields) ...[
                  Text(_fieldLabel(field), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  SelectableText(
                    _value(value[field], field: field),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                ],
              OutlinedButton.icon(
                onPressed: applying || loadingDraft ? null : select,
                icon: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                ),
                label: Text(
                  _deleted(value)
                      ? 'Keep deletion'
                      : _deleted(record.local) ||
                            record.candidates.values.any(_deleted)
                      ? 'Restore this record'
                      : title.startsWith('This')
                      ? 'Keep this device'
                      : 'Keep cloud version',
                ),
              ),
              DisclosureTile(
                key: PageStorageKey('complete:${record.id}:$title'),
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
        _entityLabel(record.entity);
    final deleted =
        _deleted(record.local) || record.candidates.values.any(_deleted);
    final fields = record.review.conflicts
        .where((c) => c.field != r'$record')
        .map((c) => _fieldLabel(c.field))
        .toSet();
    final icon = switch (record.entity) {
      'tasks' => Icons.task_alt_outlined,
      'fixed_events' => Icons.event_outlined,
      'goals' => Icons.flag_outlined,
      'habits' => Icons.insights_outlined,
      'deletion_tombstones' => Icons.delete_outline,
      _ => Icons.account_tree_outlined,
    };
    Widget choice(
      String label,
      SyncResolutionChoice choice,
      Map<String, Object?>? value,
    ) {
      final selected =
          choices.containsKey(record.id) &&
          choices[record.id]!.revision == choice.revision;
      return OutlinedButton.icon(
        onPressed: applying || loadingDraft
            ? null
            : () => _choose(record.id, choice),
        style: _deleted(value)
            ? OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error)
            : null,
        icon: Icon(
          selected
              ? Icons.check_circle
              : _deleted(value)
              ? Icons.delete_outline
              : Icons.radio_button_unchecked,
          size: 18,
        ),
        label: Text(
          '${_deleted(value)
              ? 'Keep deletion'
              : deleted
              ? 'Restore'
              : 'Keep'} - $label',
        ),
      );
    }

    return Card(
      key: ValueKey(record.id),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('$title', style: theme.textTheme.titleMedium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _entityLabel(record.entity),
              style: theme.textTheme.labelMedium,
            ),
            Text(
              deleted
                  ? 'Deleted on one or more devices'
                  : record.consequence
                  ? 'Affected by a related change'
                  : 'Edited on multiple devices',
              style: theme.textTheme.bodySmall,
            ),
            if (fields.isNotEmpty)
              Text(
                'Differs: ${fields.take(3).join(', ')}${fields.length > 3 ? ' and ${fields.length - 3} more' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                choice(
                  'This device',
                  const SyncResolutionChoice.local(),
                  record.local,
                ),
                for (final id in record.remoteHeads)
                  choice(
                    record.remoteHeads.length == 1
                        ? 'Cloud'
                        : 'Cloud ${id.substring(0, math.min(8, id.length))}',
                    SyncResolutionChoice.revision(id),
                    record.candidates[id],
                  ),
              ],
            ),
            DisclosureTile(
              key: PageStorageKey('details:${record.id}'),
              tilePadding: EdgeInsets.zero,
              title: const Text('View details'),
              children: [
                Text(
                  '${_entityLabel(record.entity)} - ${record.key}',
                  style: theme.textTheme.bodySmall,
                ),
                if (record.local?['updated_at'] != null)
                  Text(
                    'This device modified: ${record.local!['updated_at']}',
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
                        () => _choose(
                          record.id,
                          const SyncResolutionChoice.local(),
                        ),
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
                          () => _choose(
                            record.id,
                            SyncResolutionChoice.revision(id),
                          ),
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
                  DisclosureTile(
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
          ],
        ),
      ),
    );
  }

  Future<void> _apply() async {
    setState(() => applying = true);
    try {
      final result = await widget.controller.resolve(review, choices);
      if (!mounted) return;
      if (result?.state == SyncApplyState.applied) {
        // The database decision has committed. Draft cleanup must not report
        // that a committed decision failed; its old review token is stale.
        try {
          await widget.controller.saveDecisionDraft(review, const {});
        } catch (_) {}
        if (!mounted) return;
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
            onPressed: applying || loadingDraft
                ? null
                : () => setState(() {
                    confirming = false;
                    for (final record in decisionRecords) {
                      choices[record.id] = const SyncResolutionChoice.local();
                    }
                    _saveDraft();
                  }),
            child: Text('Keep this device for all (${decisionRecords.length})'),
          ),
          TextButton(
            onPressed: applying || loadingDraft || !canBulkCloud
                ? null
                : () => setState(() {
                    confirming = false;
                    for (final record in decisionRecords) {
                      choices[record.id] = SyncResolutionChoice.revision(
                        record.remoteHeads.single,
                      );
                    }
                    _saveDraft();
                  }),
            child: Text('Keep cloud for all (${decisionRecords.length})'),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final canBulkCloud = decisionRecords.every(
      (r) => r.remoteHeads.length == 1,
    );
    final compactReview =
        screen.width >= 800 &&
        decisionRecords.length == 1 &&
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
    final ready =
        !loadingDraft &&
        requiredRecords.every((r) => choices.containsKey(r.id));
    final deletions = review.records.where((r) {
      final choice = choices[r.id];
      return choice != null &&
          _deleted(
            choice.revision == null ? r.local : r.candidates[choice.revision],
          );
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
          height: math.min(
            compactReview
                ? 500 * MediaQuery.textScalerOf(context).scale(14) / 14
                : 850,
            screen.height - 48,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!scrollingTitle) ...[title, const SizedBox(height: 8)],
                Expanded(
                  child: ScrollEdgeFade(
                    child: confirming
                        ? FadingScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (scrollingTitle) ...[
                                  title,
                                  const SizedBox(height: 12),
                                ],
                                Text(
                                  'Apply ${choices.length} decisions?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'The chosen values will replace competing changes on your synced devices.${deletions > 0 ? ' $deletions records will be deleted.' : ''} Your separate backups are kept.',
                                ),
                              ],
                            ),
                          )
                        : FadingListView.builder(
                            itemCount: decisionRecords.length + 1,
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
                                : _record(decisionRecords[i - 1]),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${choices.length} of ${decisionRecords.length} records selected',
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
