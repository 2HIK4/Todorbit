import '../../data/life_repository.dart';
import '../shared/scroll_edge_fade.dart';
import '../shared/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/trash.dart';

class ArchiveTrashDialog extends ConsumerStatefulWidget {
  const ArchiveTrashDialog({super.key});

  @override
  ConsumerState<ArchiveTrashDialog> createState() => _ArchiveTrashDialogState();
}

class _ArchiveTrashDialogState extends ConsumerState<ArchiveTrashDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool busy = false;
  String? error;
  bool selecting = false;
  final Set<String> _selectedArchiveSeries = {};
  final Set<String> _selectedArchiveTasks = {};
  final Set<String> _selectedTrash = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _clearSelection();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    _selectedArchiveSeries.clear();
    _selectedArchiveTasks.clear();
    _selectedTrash.clear();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> _confirmPurge(TrashItem item) async {
    return await showDialog<bool>(
          context: context,
          animationStyle: AppMotion.style(context),
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Permanently delete?'),
            content: Text(
              'Permanently delete ${item.name}? This cannot be undone. '
              'Linked records can block deletion. The 30 day retention period '
              'does not trigger automatic removal.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Permanently delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _confirmEmptyTrash(AppController controller) async {
    final confirmedItems = List.of(controller.trashItems);
    final count = confirmedItems.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: Text(
          'Permanently delete all $count item${count == 1 ? '' : 's'} in Trash? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() async {
        await controller.repository.purgeTrashSelection(confirmedItems);
        await controller.refresh();
        _clearSelection();
      });
    }
  }

  Future<void> _deleteSelectedArchive(AppController controller) async {
    final confirmedSeries = controller.archivedSeries
        .where((s) => _selectedArchiveSeries.contains(s.familyId))
        .toList();
    final confirmedTasks = controller.archivedTasks
        .where((t) => _selectedArchiveTasks.contains(t.id))
        .toList();
    final seriesCount = _selectedArchiveSeries.length;
    final taskCount = _selectedArchiveTasks.length;
    final total = seriesCount + taskCount;
    if (total == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move selected items to Trash?'),
        content: Text(
          'Move $total selected item${total == 1 ? '' : 's'} to Trash? Their tasks will be moved to Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() async {
        await controller.repository.deleteArchivedSelection(
          confirmedSeries,
          confirmedTasks,
        );
        await controller.refresh();
        _clearSelection();
        selecting = false;
      });
    }
  }

  Future<void> _deleteSelectedTrash(AppController controller) async {
    final confirmedItems = controller.trashItems
        .where((item) => _selectedTrash.contains(item.id))
        .toList();
    final count = _selectedTrash.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently delete selected?'),
        content: Text(
          'Permanently delete $count selected item${count == 1 ? '' : 's'}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Permanently delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() async {
        await controller.repository.purgeTrashSelection(confirmedItems);
        await controller.refresh();
        _clearSelection();
        selecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final isArchiveTab = _tabController.index == 0;
    final totalArchive =
        controller.archivedSeries.length + controller.archivedTasks.length;
    final totalTrash = controller.trashItems.length;
    final selectedArchiveCount =
        _selectedArchiveSeries.length + _selectedArchiveTasks.length;
    final selectedTrashCount = _selectedTrash.length;

    final allArchiveSelected =
        totalArchive > 0 && selectedArchiveCount == totalArchive;
    final allTrashSelected = totalTrash > 0 && selectedTrashCount == totalTrash;

    return Dialog(
      child: SizedBox(
        width: 720,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Archive and Trash',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (!selecting) ...[
                    TextButton.icon(
                      onPressed: () => setState(() => selecting = true),
                      icon: const Icon(Icons.checklist, size: 18),
                      label: const Text('Select'),
                    ),
                    if (!isArchiveTab && totalTrash > 0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: busy
                            ? null
                            : () => _confirmEmptyTrash(controller),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('Empty Trash'),
                      ),
                  ] else ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selecting = false;
                          _clearSelection();
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Archive'),
                      if (totalArchive > 0) ...[
                        const SizedBox(width: 6),
                        Badge.count(count: totalArchive),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Trash'),
                      if (totalTrash > 0) ...[
                        const SizedBox(width: 6),
                        Badge.count(count: totalTrash),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (selecting)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Checkbox(
                      value: isArchiveTab
                          ? allArchiveSelected
                          : allTrashSelected,
                      tristate: isArchiveTab
                          ? (selectedArchiveCount > 0 && !allArchiveSelected)
                          : (selectedTrashCount > 0 && !allTrashSelected),
                      onChanged: (val) {
                        setState(() {
                          if (isArchiveTab) {
                            if (allArchiveSelected) {
                              _selectedArchiveSeries.clear();
                              _selectedArchiveTasks.clear();
                            } else {
                              _selectedArchiveSeries.addAll(
                                controller.archivedSeries.map(
                                  (s) => s.familyId,
                                ),
                              );
                              _selectedArchiveTasks.addAll(
                                controller.archivedTasks.map((t) => t.id),
                              );
                            }
                          } else {
                            if (allTrashSelected) {
                              _selectedTrash.clear();
                            } else {
                              _selectedTrash.addAll(
                                controller.trashItems.map((item) => item.id),
                              );
                            }
                          }
                        });
                      },
                    ),
                    Text(
                      isArchiveTab
                          ? '$selectedArchiveCount of $totalArchive selected'
                          : '$selectedTrashCount of $totalTrash selected',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (isArchiveTab && selectedArchiveCount > 0)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .errorContainer,
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onErrorContainer,
                        ),
                        onPressed: busy
                            ? null
                            : () => _deleteSelectedArchive(controller),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text('Move to Trash ($selectedArchiveCount)'),
                      ),
                    if (!isArchiveTab && selectedTrashCount > 0)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onError,
                        ),
                        onPressed: busy
                            ? null
                            : () => _deleteSelectedTrash(controller),
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          size: 18,
                        ),
                        label: Text('Permanently delete ($selectedTrashCount)'),
                      ),
                  ],
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  controller.archivedTasks.isEmpty &&
                          controller.archivedSeries.isEmpty
                      ? const Center(child: Text('Archive is empty'))
                      : FadingListView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                            for (final series in controller.archivedSeries)
                              ListTile(
                                leading: selecting
                                    ? Checkbox(
                                        value: _selectedArchiveSeries.contains(
                                          series.familyId,
                                        ),
                                        onChanged: (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedArchiveSeries.add(
                                                series.familyId,
                                              );
                                            } else {
                                              _selectedArchiveSeries.remove(
                                                series.familyId,
                                              );
                                            }
                                          });
                                        },
                                      )
                                    : const Icon(Icons.repeat_outlined),
                                title: Text(series.title),
                                subtitle: Text(
                                  'Entire series - ${series.occurrences} occurrences',
                                ),
                                onTap: selecting
                                    ? () {
                                        setState(() {
                                          if (_selectedArchiveSeries.contains(
                                            series.familyId,
                                          )) {
                                            _selectedArchiveSeries.remove(
                                              series.familyId,
                                            );
                                          } else {
                                            _selectedArchiveSeries.add(
                                              series.familyId,
                                            );
                                          }
                                        });
                                      }
                                    : null,
                                trailing: selecting
                                    ? null
                                    : Wrap(
                                        spacing: 4,
                                        children: [
                                          OutlinedButton(
                                            onPressed: busy
                                                ? null
                                                : () => _run(
                                                    () => controller
                                                        .restoreArchivedSeries(
                                                          series,
                                                        ),
                                                  ),
                                            child: const Text('Restore'),
                                          ),
                                          IconButton(
                                            tooltip: 'Move to Trash',
                                            onPressed: busy
                                                ? null
                                                : () => _run(
                                                    () => controller
                                                        .deleteArchivedSeries(
                                                          series,
                                                        ),
                                                  ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            for (final task in controller.archivedTasks)
                              ListTile(
                                leading: selecting
                                    ? Checkbox(
                                        value: _selectedArchiveTasks.contains(
                                          task.id,
                                        ),
                                        onChanged: (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedArchiveTasks.add(
                                                task.id,
                                              );
                                            } else {
                                              _selectedArchiveTasks.remove(
                                                task.id,
                                              );
                                            }
                                          });
                                        },
                                      )
                                    : const Icon(Icons.archive_outlined),
                                title: Text(task.title),
                                subtitle: Text(
                                  task.recurrenceSeriesId == null
                                      ? task.status.name
                                      : 'Occurrence - ${task.status.name}',
                                ),
                                onTap: selecting
                                    ? () {
                                        setState(() {
                                          if (_selectedArchiveTasks.contains(
                                            task.id,
                                          )) {
                                            _selectedArchiveTasks.remove(
                                              task.id,
                                            );
                                          } else {
                                            _selectedArchiveTasks.add(task.id);
                                          }
                                        });
                                      }
                                    : null,
                                trailing: selecting
                                    ? null
                                    : Wrap(
                                        spacing: 4,
                                        children: [
                                          OutlinedButton(
                                            onPressed: busy
                                                ? null
                                                : () => _run(
                                                    () => controller
                                                        .restoreArchivedTask(
                                                          task,
                                                        ),
                                                  ),
                                            child: const Text('Restore'),
                                          ),
                                          IconButton(
                                            tooltip: 'Move to Trash',
                                            onPressed: busy
                                                ? null
                                                : () => _run(
                                                    () => controller
                                                        .deleteArchivedTask(
                                                          task,
                                                        ),
                                                  ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                          ],
                        ),
                  controller.trashItems.isEmpty
                      ? const Center(child: Text('Trash is empty'))
                      : FadingListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: controller.trashItems.length,
                          itemBuilder: (context, index) {
                            final item = controller.trashItems[index];
                            final children =
                                item.kind == TrashKind.project ||
                                    item.kind == TrashKind.category ||
                                    item.kind == TrashKind.series
                                ? ' - ${item.affectedTasks} task${item.affectedTasks == 1 ? '' : 's'} in this ${item.kind.name}'
                                : '';
                            final isSelected = _selectedTrash.contains(item.id);
                            return ListTile(
                              leading: selecting
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedTrash.add(item.id);
                                          } else {
                                            _selectedTrash.remove(item.id);
                                          }
                                        });
                                      },
                                    )
                                  : const Icon(Icons.delete_outline),
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.kind.name} - Deleted ${item.deletedAt.toLocal().toString().split('.').first}'
                                '$children - Retain until at least ${item.retentionEndsAt.toLocal().toString().split(' ').first}',
                              ),
                              isThreeLine: true,
                              onTap: selecting
                                  ? () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedTrash.remove(item.id);
                                        } else {
                                          _selectedTrash.add(item.id);
                                        }
                                      });
                                    }
                                  : null,
                              trailing: selecting
                                  ? null
                                  : Wrap(
                                      spacing: 4,
                                      children: [
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => _run(
                                                  () => controller
                                                      .restoreTrashItem(item),
                                                ),
                                          child: const Text('Restore'),
                                        ),
                                        IconButton(
                                          tooltip: 'Permanently delete',
                                          onPressed: busy
                                              ? null
                                              : () async {
                                                  if (await _confirmPurge(
                                                    item,
                                                  )) {
                                                    await _run(
                                                      () => controller
                                                          .permanentlyDelete(
                                                            item,
                                                          ),
                                                    );
                                                  }
                                                },
                                          icon: const Icon(
                                            Icons.delete_forever_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
