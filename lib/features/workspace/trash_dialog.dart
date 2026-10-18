import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/trash.dart';

class ArchiveTrashDialog extends ConsumerStatefulWidget {
  const ArchiveTrashDialog({super.key});

  @override
  ConsumerState<ArchiveTrashDialog> createState() => _ArchiveTrashDialogState();
}

class _ArchiveTrashDialogState extends ConsumerState<ArchiveTrashDialog> {
  bool busy = false;
  String? error;

  Future<void> _run(Future<void> Function() action) async {
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
          builder: (context) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return Dialog(
      child: SizedBox(
        width: 690,
        height: 590,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Archive and Trash',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Archive'),
                  Tab(text: 'Trash'),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    controller.archivedTasks.isEmpty &&
                            controller.archivedSeries.isEmpty
                        ? const Center(child: Text('Archive is empty'))
                        : ListView(
                            children: [
                              for (final series in controller.archivedSeries)
                                ListTile(
                                  leading: const Icon(Icons.repeat_outlined),
                                  title: Text(series.title),
                                  subtitle: Text(
                                    'Entire series - ${series.occurrences} occurrences',
                                  ),
                                  trailing: OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => _run(
                                            () => controller
                                                .restoreArchivedSeries(series),
                                          ),
                                    child: const Text('Restore'),
                                  ),
                                ),
                              for (final task in controller.archivedTasks)
                                ListTile(
                                  leading: const Icon(Icons.archive_outlined),
                                  title: Text(task.title),
                                  subtitle: Text(
                                    task.recurrenceSeriesId == null
                                        ? task.status.name
                                        : 'Occurrence - ${task.status.name}',
                                  ),
                                  trailing: OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => _run(
                                            () => controller
                                                .restoreArchivedTask(task),
                                          ),
                                    child: const Text('Restore'),
                                  ),
                                ),
                            ],
                          ),
                    controller.trashItems.isEmpty
                        ? const Center(child: Text('Trash is empty'))
                        : ListView.builder(
                            itemCount: controller.trashItems.length,
                            itemBuilder: (context, index) {
                              final item = controller.trashItems[index];
                              final children =
                                  item.kind == TrashKind.project ||
                                      item.kind == TrashKind.category ||
                                      item.kind == TrashKind.series
                                  ? ' - ${item.affectedTasks} task${item.affectedTasks == 1 ? '' : 's'} in this ${item.kind.name}'
                                  : '';
                              return ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: Text(item.name),
                                subtitle: Text(
                                  '${item.kind.name} - Deleted ${item.deletedAt.toLocal().toString().split('.').first}'
                                  '$children - Retain until at least ${item.retentionEndsAt.toLocal().toString().split(' ').first}',
                                ),
                                isThreeLine: true,
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => _run(
                                              () => controller.restoreTrashItem(
                                                item,
                                              ),
                                            ),
                                      child: const Text('Restore'),
                                    ),
                                    IconButton(
                                      tooltip: 'Permanently delete',
                                      onPressed: busy
                                          ? null
                                          : () async {
                                              if (await _confirmPurge(item)) {
                                                await _run(
                                                  () => controller
                                                      .permanentlyDelete(item),
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
      ),
    );
  }
}
