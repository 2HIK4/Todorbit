import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/task_view_preferences.dart';

class TaskViewSettingsDialog extends ConsumerWidget {
  const TaskViewSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final preferences = controller.taskViewPreferences;
    Future<void> save(TaskViewPreferences value) async {
      try {
        await controller.setTaskViewPreferences(value);
      } catch (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save setting: $failure')),
          );
        }
      }
    }
    return AlertDialog(
      title: const Text('Task display and defaults'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<NewTaskPlannedDay>(
              initialValue: preferences.newTaskPlannedDay,
              decoration: const InputDecoration(
                labelText: 'New task planned day',
              ),
              items: const [
                DropdownMenuItem(
                  value: NewTaskPlannedDay.today,
                  child: Text('Today'),
                ),
                DropdownMenuItem(
                  value: NewTaskPlannedDay.noDate,
                  child: Text('No Date'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  save(
                    preferences.copyWith(newTaskPlannedDay: value),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Keep completed tasks visible'),
              subtitle: const Text(
                'Show them faded at the bottom of eligible lists.',
              ),
              value: preferences.keepCompletedVisible,
              onChanged: (value) => save(
                preferences.copyWith(keepCompletedVisible: value),
              ),
            ),
            SwitchListTile(
              title: const Text('Spelling review'),
              subtitle: const Text(
                'Use the local Windows English dictionary when requested.',
              ),
              value: preferences.spellCheckEnabled,
              onChanged: (value) => save(
                preferences.copyWith(spellCheckEnabled: value),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
