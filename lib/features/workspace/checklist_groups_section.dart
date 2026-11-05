import '../shared/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/life_repository.dart';
import '../../domain/task_composition.dart';
import '../shared/text_prompt_dialog.dart';

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
          label: const Text('Add checklist'),
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
                children: [
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () async {
                          final title = await _name(
                            context,
                            'Checklist name',
                            group.title,
                          );
                          if (title != null) {
                            await run(
                              () => c.repository.renameChecklistGroup(
                                group,
                                title,
                              ),
                            );
                          }
                        },
                        child: const Text('Rename'),
                      ),
                      IconButton(
                        tooltip: 'Move checklist up',
                        onPressed: i == 0
                            ? null
                            : () => run(
                                () =>
                                    c.repository.moveChecklistGroup(group, -1),
                              ),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: 'Move checklist down',
                        onPressed: i == groups.length - 1
                            ? null
                            : () => run(
                                () => c.repository.moveChecklistGroup(group, 1),
                              ),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      TextButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            animationStyle: AppMotion.style(context),
                            builder: (context) => AlertDialog(
                              title: const Text('Remove checklist?'),
                              content: Text(
                                'Remove ${group.title} and its ${items.length} items? Subtasks are kept.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await run(
                              () => c.repository.removeChecklistGroup(
                                group,
                                items,
                              ),
                            );
                          }
                        },
                        child: const Text('Remove checklist'),
                      ),
                    ],
                  ),
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
                          if (action == 'remove') {
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
          label: const Text('Add checklist'),
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
            children: [
              Wrap(
                children: [
                  TextButton(
                    onPressed: () async {
                      final title = await _name(
                        context,
                        'Checklist name',
                        groups[i].title,
                      );
                      if (title != null && context.mounted) {
                        replace(i, DraftChecklistGroup(title, groups[i].items));
                      }
                    },
                    child: const Text('Rename'),
                  ),
                  IconButton(
                    tooltip: 'Move checklist up',
                    onPressed: i == 0
                        ? null
                        : () {
                            final next = List.of(groups);
                            next.insert(i - 1, next.removeAt(i));
                            onChanged(next);
                          },
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Move checklist down',
                    onPressed: i == groups.length - 1
                        ? null
                        : () {
                            final next = List.of(groups);
                            next.insert(i + 1, next.removeAt(i));
                            onChanged(next);
                          },
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  TextButton(
                    onPressed: () {
                      final next = List.of(groups)..removeAt(i);
                      onChanged(next);
                    },
                    child: const Text('Remove checklist'),
                  ),
                ],
              ),
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
                    onSelected: (action) {
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
