import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';

class QuickSearchDialog extends ConsumerStatefulWidget {
  const QuickSearchDialog({super.key});

  @override
  ConsumerState<QuickSearchDialog> createState() => _QuickSearchDialogState();
}

class _QuickSearchDialogState extends ConsumerState<QuickSearchDialog> {
  final query = TextEditingController();

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  List<_SearchMatch> _matches(AppController controller) {
    final needle = query.text.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final categories = {
      for (final item in controller.categories) item.id: item,
    };
    final projects = {for (final item in controller.projects) item.id: item};
    final matches = <_SearchMatch>[];
    for (final category in controller.categories) {
      if (category.name.toLowerCase().contains(needle)) {
        matches.add(
          _SearchMatch(
            title: category.name,
            subtitle: 'Category',
            icon: Icons.folder_outlined,
            rank: category.name.toLowerCase().startsWith(needle) ? 0 : 2,
            open: () =>
                controller.navigate(WorkspaceView.category, id: category.id),
          ),
        );
      }
    }
    for (final project in controller.projects) {
      if (project.name.toLowerCase().contains(needle)) {
        matches.add(
          _SearchMatch(
            title: project.name,
            subtitle: 'Project · ${categories[project.categoryId]?.name ?? ''}',
            icon: Icons.folder_open_outlined,
            rank: project.name.toLowerCase().startsWith(needle) ? 0 : 2,
            open: () =>
                controller.navigate(WorkspaceView.project, id: project.id),
          ),
        );
      }
    }
    for (final task in controller.tasks) {
      final title = task.title.toLowerCase();
      final category = categories[task.categoryId]?.name ?? '';
      final project = projects[task.projectId]?.name ?? '';
      final content = '${task.notes} $category $project'.toLowerCase();
      if (!title.contains(needle) && !content.contains(needle)) continue;
      matches.add(
        _SearchMatch(
          title: task.title,
          subtitle: [
            task.isOpen ? 'Task' : 'Closed task',
            if (project.isNotEmpty)
              project
            else if (category.isNotEmpty)
              category,
            if (task.scheduledDate != null) 'Plan ${task.scheduledDate}',
          ].join(' · '),
          icon: task.isOpen ? Icons.check_box_outline_blank : Icons.task_alt,
          rank: title.startsWith(needle)
              ? 0
              : title.contains(needle)
              ? 1
              : 3,
          open: () {
            controller.navigate(
              task.isOpen ? WorkspaceView.all : WorkspaceView.completed,
            );
            controller.select(task.id);
          },
        ),
      );
    }
    matches.sort((a, b) {
      final rank = a.rank.compareTo(b.rank);
      return rank != 0
          ? rank
          : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return matches.take(50).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final matches = _matches(controller);
    void open(_SearchMatch match) {
      match.open();
      Navigator.pop(context);
    }

    return Dialog(
      child: SizedBox(
        width: 620,
        height: 540,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              TextField(
                controller: query,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: 'Search tasks, categories, and projects',
                  suffixIcon: IconButton(
                    tooltip: 'Close search',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (matches.isNotEmpty) open(matches.first);
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: query.text.trim().isEmpty
                    ? const Center(child: Text('Type to find a task or place.'))
                    : matches.isEmpty
                    ? const Center(child: Text('No matches.'))
                    : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final match = matches[index];
                          return ListTile(
                            leading: Icon(match.icon),
                            title: Text(
                              match.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              match.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => open(match),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchMatch {
  const _SearchMatch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.rank,
    required this.open,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final int rank;
  final VoidCallback open;
}
