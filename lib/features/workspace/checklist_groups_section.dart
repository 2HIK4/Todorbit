import '../shared/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/life_repository.dart';
import '../../domain/task_composition.dart';
import '../shared/text_prompt_dialog.dart';

Future<bool> confirmChecklistItemRemoval(
  BuildContext context,
  String title,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove "$title" from this checklist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> _name(
  BuildContext context,
  String title, [
  String initial = '',
]) => showDialog<String>(
  context: context,
  animationStyle: AppMotion.style(context),
  builder: (_) => TextPromptDialog(
    title: title,
    initial: initial,
    save: (value) async {
      if (value.trim().isEmpty) throw ArgumentError('Enter a name');
    },
  ),
);

class _ChecklistMenu extends StatelessWidget {
  const _ChecklistMenu({
    required this.title,
    required this.count,
    required this.rename,
    required this.remove,
    this.up,
    this.down,
  });
  final String title;
  final int count;
  final Future<void> Function() rename, remove;
  final Future<void> Function()? up, down;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Checklist actions: $title',
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'rename', child: Text('Rename')),
      PopupMenuItem(
        value: 'up',
        enabled: up != null,
        child: const Text('Move up'),
      ),
      PopupMenuItem(
        value: 'down',
        enabled: down != null,
        child: const Text('Move down'),
      ),
      const PopupMenuItem(value: 'remove', child: Text('Remove checklist')),
    ],
    onSelected: (action) async {
      if (action == 'rename') await rename();
      if (action == 'up') await up?.call();
      if (action == 'down') await down?.call();
      if (action == 'remove') {
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove checklist?'),
            content: Text(
              'Remove $title and its $count items? Subtasks are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed == true) await remove();
      }
    },
  );
}

class ChecklistGroupsSection extends ConsumerWidget {
  const ChecklistGroupsSection({super.key, required this.taskId});
  final String taskId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
        await c.refresh();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Checklist could not be changed: $error')),
          );
        }
      }
    }

    final groups = c.checklistGroups.where((g) => g.taskId == taskId).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('New checklist'),
          onPressed: () async {
            final title = await _name(context, 'New checklist');
            if (title != null) {
              await run(() async {
                await c.repository.addChecklistGroup(taskId, title);
              });
            }
          },
        ),
        for (var i = 0; i < groups.length; i++)
          Builder(
            builder: (context) {
              final group = groups[i];
              final items = c.checklistItems
                  .where((item) => item.groupId == group.id)
                  .toList();
              return ExpansionTile(
                key: PageStorageKey(group.id),
                title: Text(group.title),
                subtitle: Text(
                  '${items.where((item) => item.done).length}/${items.length} complete',
                ),
                trailing: _ChecklistMenu(
                  title: group.title,
                  count: items.length,
                  rename: () async {
                    final title = await _name(
                      context,
                      'Checklist name',
                      group.title,
                    );
                    if (title != null) {
                      await run(
                        () => c.repository.renameChecklistGroup(group, title),
                      );
                    }
                  },
                  up: i == 0
                      ? null
                      : () => run(
                          () => c.repository.moveChecklistGroup(group, -1),
                        ),
                  down: i == groups.length - 1
                      ? null
                      : () => run(
                          () => c.repository.moveChecklistGroup(group, 1),
                        ),
                  remove: () => run(
                    () => c.repository.removeChecklistGroup(group, items),
                  ),
                ),
                children: [
                  for (var n = 0; n < items.length; n++)
                    CheckboxListTile(
                      value: items[n].done,
                      title: Text(items[n].title),
                      onChanged: (done) => run(
                        () => c.repository.updateChecklistItem(
                          items[n],
                          done: done,
                        ),
                      ),
                      secondary: PopupMenuButton<String>(
                        tooltip: 'Checklist item actions',
                        onSelected: (action) async {
                          if (action == 'edit') {
                            final title = await _name(
                              context,
                              'Edit checklist item',
                              items[n].title,
                            );
                            if (title != null) {
                              await run(
                                () => c.repository.updateChecklistItem(
                                  items[n],
                                  title: title,
                                ),
                              );
                            }
                          }
                          if (action == 'remove' &&
                              context.mounted &&
                              await confirmChecklistItemRemoval(
                                context,
                                items[n].title,
                              )) {
                            if (!context.mounted) return;
                            await run(
                              () => c.repository.removeChecklistItem(items[n]),
                            );
                          }
                          if (action == 'up' || action == 'down') {
                            await run(
                              () => c.repository.moveChecklistItem(
                                items[n],
                                action == 'up' ? -1 : 1,
                              ),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          if (n > 0)
                            const PopupMenuItem(
                              value: 'up',
                              child: Text('Move up'),
                            ),
                          if (n < items.length - 1)
                            const PopupMenuItem(
                              value: 'down',
                              child: Text('Move down'),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                    onPressed: () async {
                      final title = await _name(context, 'Checklist item');
                      if (title != null) {
                        await run(
                          () => c.repository.addChecklistItem(
                            taskId,
                            title,
                            groupId: group.id,
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class DraftChecklistGroups extends StatelessWidget {
  const DraftChecklistGroups({
    super.key,
    required this.groups,
    required this.onChanged,
  });
  final List<DraftChecklistGroup> groups;
  final ValueChanged<List<DraftChecklistGroup>> onChanged;
  @override
  Widget build(BuildContext context) {
    void replace(int i, DraftChecklistGroup group) {
      final next = List.of(groups);
      next[i] = DraftChecklistGroup(
        group.title,
        group.items,
        identity: groups[i].identity,
      );
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('New checklist'),
          onPressed: () async {
            final title = await _name(context, 'New checklist');
            if (title != null && context.mounted) {
              onChanged([...groups, DraftChecklistGroup(title, const [])]);
            }
          },
        ),
        for (var i = 0; i < groups.length; i++)
          ExpansionTile(
            key: ObjectKey(groups[i].identity),
            initiallyExpanded: true,
            title: Text(groups[i].title),
            subtitle: Text('${groups[i].items.length} items'),
            trailing: _ChecklistMenu(
              title: groups[i].title,
              count: groups[i].items.length,
              rename: () async {
                final title = await _name(
                  context,
                  'Checklist name',
                  groups[i].title,
                );
                if (title != null && context.mounted) {
                  replace(i, DraftChecklistGroup(title, groups[i].items));
                }
              },
              up: i == 0
                  ? null
                  : () async {
                      final next = List.of(groups);
                      next.insert(i - 1, next.removeAt(i));
                      onChanged(next);
                    },
              down: i == groups.length - 1
                  ? null
                  : () async {
                      final next = List.of(groups);
                      next.insert(i + 1, next.removeAt(i));
                      onChanged(next);
                    },
              remove: () async => onChanged(List.of(groups)..removeAt(i)),
            ),
            children: [
              for (var n = 0; n < groups[i].items.length; n++)
                ListTile(
                  title: Text(groups[i].items[n]),
                  onTap: () async {
                    final title = await _name(
                      context,
                      'Edit checklist item',
                      groups[i].items[n],
                    );
                    if (title != null && context.mounted) {
                      final items = List.of(groups[i].items);
                      items[n] = title;
                      replace(i, DraftChecklistGroup(groups[i].title, items));
                    }
                  },
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Draft checklist item actions',
                    itemBuilder: (_) => [
                      if (n > 0)
                        const PopupMenuItem(
                          value: 'up',
                          child: Text('Move up'),
                        ),
                      if (n < groups[i].items.length - 1)
                        const PopupMenuItem(
                          value: 'down',
                          child: Text('Move down'),
                        ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove'),
                      ),
                    ],
                    onSelected: (action) async {
                      if (action == 'remove' &&
                          !await confirmChecklistItemRemoval(
                            context,
                            groups[i].items[n],
                          )) {
                        return;
                      }
                      if (!context.mounted) return;
                      final items = List.of(groups[i].items);
                      final title = items.removeAt(n);
                      if (action != 'remove') {
                        items.insert(n + (action == 'up' ? -1 : 1), title);
                      }
                      replace(i, DraftChecklistGroup(groups[i].title, items));
                    },
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
                onPressed: () async {
                  final title = await _name(context, 'Checklist item');
                  if (title != null && context.mounted) {
                    replace(
                      i,
                      DraftChecklistGroup(groups[i].title, [
                        ...groups[i].items,
                        title,
                      ]),
                    );
                  }
                },
              ),
            ],
          ),
      ],
    );
  }
}
