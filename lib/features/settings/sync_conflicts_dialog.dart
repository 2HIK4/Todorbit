import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/sync_controller.dart';
import '../../data/sync_exchange_models.dart';

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
  bool applying = false, handled = false;
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

  String _value(Object? value) => value == null
      ? 'Deleted / not present'
      : const JsonEncoder.withIndent('  ').convert(value);
  Widget _version(
    String title,
    Object? value,
    bool selected,
    VoidCallback select,
  ) => Card(
    color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SelectableText(_value(value)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: applying ? null : select,
            icon: Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
            ),
            label: Text(
              selected
                  ? 'Selected'
                  : title.startsWith('This')
                  ? 'Keep This Device'
                  : 'Keep Cloud',
            ),
          ),
        ],
      ),
    ),
  );
  Widget _record(SyncConflictRecord record) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${record.entity.replaceAll('_', ' ')} · ${record.local?['title'] ?? record.local?['name'] ?? record.key}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            record.review.needsDecision
                ? 'Different: ${record.review.conflicts.map((c) => c.field == r'$record' ? 'record / deletion' : c.field.replaceAll('_', ' ')).join(', ')}'
                : 'Related record. Compatible changes are preserved unless a whole-record decision is needed.',
          ),
          if (record.review.conflicts.isNotEmpty)
            ExpansionTile(
              title: const Text('Previous / base values'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    _value({
                      for (final conflict in record.review.conflicts)
                        conflict.field: conflict.base,
                    }),
                  ),
                ),
              ],
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final versions = <Widget>[
                _version(
                  'This Device',
                  record.local,
                  choices.containsKey(record.id) &&
                      choices[record.id]!.revision == null,
                  () => setState(
                    () =>
                        choices[record.id] = const SyncResolutionChoice.local(),
                  ),
                ),
                for (final id in record.remoteHeads)
                  _version(
                    record.consequence
                        ? 'If the cloud action is applied'
                        : record.remoteHeads.length == 1
                        ? 'Cloud'
                        : 'Cloud ${id.substring(0, math.min(8, id.length))}',
                    record.candidates[id],
                    choices[record.id]?.revision == id,
                    () => setState(
                      () => choices[record.id] = SyncResolutionChoice.revision(
                        id,
                      ),
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
        ],
      ),
    ),
  );

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
        'Both versions are retained. Select which conflicting values to keep. Independent compatible changes will remain. Bulk buttons only change selections.',
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
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: applying
                ? null
                : () => setState(() {
                    for (final record in review.records) {
                      choices[record.id] = const SyncResolutionChoice.local();
                    }
                  }),
            child: const Text('Use This Device for All'),
          ),
          TextButton(
            onPressed: applying || !canBulkCloud
                ? null
                : () => setState(() {
                    for (final record in review.records) {
                      choices[record.id] = SyncResolutionChoice.revision(
                        record.remoteHeads.single,
                      );
                    }
                  }),
            child: const Text('Use Cloud for All'),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final canBulkCloud = review.records.every((r) => r.remoteHeads.length == 1);
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
          height: math.min(850, screen.height - 48),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Resolve sync conflicts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: review.records.length + 1,
                    itemBuilder: (_, i) => i == 0
                        ? _header(canBulkCloud)
                        : _record(review.records[i - 1]),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: applying ? null : _later,
                      child: const Text('Resolve Later'),
                    ),
                    FilledButton(
                      onPressed:
                          applying || choices.isEmpty || review.reason != null
                          ? null
                          : _apply,
                      child: Text(
                        applying ? 'Saving decisions…' : 'Apply Selected',
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
