import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
import '../../domain/templates.dart';

Future<void> showSaveTemplateDialog(
  BuildContext context, {
  required String sourceName,
  required Future<void> Function(String name) save,
}) async {
  var name = sourceName;
  var busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Save reusable template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Copies the current definition. Completion, work history, planned sessions, and external project links are not included.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: sourceName,
              decoration: const InputDecoration(labelText: 'Template name'),
              onChanged: (value) => name = value,
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setDialogState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await save(name);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (failure) {
                      if (dialogContext.mounted) {
                        setDialogState(() => error = '$failure');
                      }
                    } finally {
                      if (dialogContext.mounted) {
                        setDialogState(() => busy = false);
                      }
                    }
                  },
            child: const Text('Save template'),
          ),
        ],
      ),
    ),
  );
}

class TemplatesDialog extends ConsumerStatefulWidget {
  const TemplatesDialog({super.key});

  @override
  ConsumerState<TemplatesDialog> createState() => _TemplatesDialogState();
}

class _TemplatesDialogState extends ConsumerState<TemplatesDialog> {
  String? error;

  Future<void> _remove(LifeTemplate template) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text(
          'Delete “${template.name}”? Existing tasks and projects remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete template'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await ref.read(appControllerProvider).deleteTemplate(template);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    }
  }

  Future<void> _apply(LifeTemplate template) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _ApplyTemplateDialog(template: template),
    );
    if (created == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(appControllerProvider).templates;
    return Dialog(
      child: SizedBox(
        width: 530,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Templates',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close templates',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Save a task from its details or a project from its menu. Apply a template here.',
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: templates.isEmpty
                    ? const Center(child: Text('No templates saved yet.'))
                    : ListView(
                        children: [
                          for (final template in templates)
                            ListTile(
                              title: Text(template.name),
                              subtitle: Text(template.summary),
                              onTap: () => _apply(template),
                              trailing: IconButton(
                                tooltip: 'Delete ${template.name}',
                                onPressed: () => _remove(template),
                                icon: const Icon(Icons.delete_outline),
                              ),
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

class _ApplyTemplateDialog extends ConsumerStatefulWidget {
  const _ApplyTemplateDialog({required this.template});
  final LifeTemplate template;

  @override
  ConsumerState<_ApplyTemplateDialog> createState() =>
      _ApplyTemplateDialogState();
}

class _ApplyTemplateDialogState extends ConsumerState<_ApplyTemplateDialog> {
  DateTime day = DateTime.now();
  String? categoryId;
  String? projectId;
  late String projectName = widget.template.kind == TemplateKind.project
      ? widget.template.payload['project_name'] as String
      : '';
  bool busy = false;
  String? error;

  Future<void> _pickDay() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => day = selected);
  }

  Future<void> _create() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(appControllerProvider)
          .instantiateTemplate(
            widget.template,
            anchorDay: localDate(day),
            categoryId: categoryId,
            projectId: widget.template.kind == TemplateKind.project
                ? null
                : projectId,
            projectName: projectName,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final template = widget.template;
    final projects = controller.projects.where(
      (item) => item.categoryId == categoryId,
    );
    final recipes = template.kind == TemplateKind.project
        ? [
            for (final raw in template.payload['tasks'] as List)
              (raw as Map).cast<String, dynamic>(),
          ]
        : [(template.payload['task'] as Map).cast<String, dynamic>()];
    final linkCount = template.kind == TemplateKind.project
        ? (template.payload['dependencies'] as List).length
        : 0;
    final externalLinks = template.kind == TemplateKind.project
        ? (template.payload['external_link_count'] as int? ?? 0)
        : 0;
    return AlertDialog(
      title: Text('Apply ${template.name}'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New IDs are created. Completion, actual work, planned sessions, and history are not copied. Date offsets are relative to the selected anchor; undated tasks stay undated.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : _pickDay,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Date anchor: ${localDate(day)}'),
              ),
              if (template.kind == TemplateKind.routine)
                const Text(
                  'For a selected-weekday routine, choose one of its scheduled weekdays.',
                ),
              if (externalLinks > 0)
                Text(
                  '$externalLinks prerequisite links to tasks outside the source project will not be copied.',
                ),
              const SizedBox(height: 12),
              AnchoredSelectField<String?>(
                isExpanded: true,
                key: ValueKey('template-category:$categoryId'),
                initialValue: categoryId,
                decoration: InputDecoration(
                  labelText: template.kind == TemplateKind.project
                      ? 'Category *'
                      : 'Category (optional)',
                ),
                items: [
                  if (template.kind != TemplateKind.project)
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Inbox'),
                    ),
                  for (final category in controller.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() {
                  categoryId = value;
                  projectId = null;
                }),
              ),
              if (template.kind == TemplateKind.project) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: projectName,
                  decoration: const InputDecoration(
                    labelText: 'New project name *',
                  ),
                  onChanged: (value) => projectName = value,
                ),
              ] else if (categoryId != null) ...[
                const SizedBox(height: 12),
                AnchoredSelectField<String?>(
                  isExpanded: true,
                  key: ValueKey('template-project:$categoryId:$projectId'),
                  initialValue: projectId,
                  decoration: const InputDecoration(
                    labelText: 'Project (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No project'),
                    ),
                    for (final project in projects)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(project.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => projectId = value),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Creates ${recipes.length} ${recipes.length == 1 ? 'task' : 'tasks'}${linkCount == 0 ? '' : ' with $linkCount internal dependencies'}:',
              ),
              for (final recipe in recipes.take(12))
                Text(
                  '• ${recipe['title']} '
                  '${recipe['scheduled_offset'] == null ? '' : '· plan ${RecurrenceRule.shiftDate(localDate(day), recipe['scheduled_offset'] as int)}'}'
                  '${recipe['deadline_offset'] == null ? '' : ' · due ${RecurrenceRule.shiftDate(localDate(day), recipe['deadline_offset'] as int)}'}',
                ),
              if (recipes.length > 12) Text('…and ${recipes.length - 12} more'),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              busy ||
                  (template.kind == TemplateKind.project && categoryId == null)
              ? null
              : _create,
          child: Text(busy ? 'Creating…' : 'Create from template'),
        ),
      ],
    );
  }
}
