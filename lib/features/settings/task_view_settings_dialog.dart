import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/task_view_preferences.dart';
import '../../domain/settings_history.dart';
import '../shared/settings_history_scope.dart';

class TaskViewSettingsDialog extends ConsumerStatefulWidget {
  const TaskViewSettingsDialog({super.key});

  @override
  ConsumerState<TaskViewSettingsDialog> createState() =>
      _TaskViewSettingsDialogState();
}

class _TaskViewSettingsDialogState
    extends ConsumerState<TaskViewSettingsDialog> {
  final history = SettingsHistory<TaskViewPreferences>(
    equal: (a, b) =>
        a.newTaskPlannedDay == b.newTaskPlannedDay &&
        a.keepCompletedVisible == b.keepCompletedVisible &&
        a.spellCheckEnabled == b.spellCheckEnabled &&
        a.compositionTextDisplay == b.compositionTextDisplay,
  );
  bool busy = false;
  Future<void> save(TaskViewPreferences value, {bool record = true}) async {
    if (busy) return;
    busy = true;
    final controller = ref.read(appControllerProvider),
        before = ref.read(appControllerProvider).taskViewPreferences;
    try {
      await controller.setTaskViewPreferences(value);
      if (record) history.record(before, value);
      if (mounted) setState(() {});
    } catch (failure) {
      history.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save setting: $failure')),
        );
      }
    } finally {
      busy = false;
    }
  }

  void travel(bool redo) {
    if (busy) return;
    final current = ref.read(appControllerProvider).taskViewPreferences;
    save(redo ? history.redo(current) : history.undo(current), record: false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final preferences = controller.taskViewPreferences;
    return SettingsHistoryScope(
      undo: () => travel(false),
      redo: () => travel(true),
      child: AlertDialog(
        title: const Text('Task display and defaults'),
        scrollable: true,
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnchoredSelectField<NewTaskPlannedDay>(
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
                    save(preferences.copyWith(newTaskPlannedDay: value));
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
                onChanged: (value) =>
                    save(preferences.copyWith(keepCompletedVisible: value)),
              ),
              SwitchListTile(
                title: const Text('Inline spelling'),
                subtitle: const Text(
                  'Underline likely misspellings using the local Windows English dictionary.',
                ),
                value: preferences.spellCheckEnabled,
                onChanged: (value) =>
                    save(preferences.copyWith(spellCheckEnabled: value)),
              ),
              const SizedBox(height: 12),
              AnchoredSelectField<CompositionTextDisplay>(
                key: ValueKey(preferences.compositionTextDisplay),
                initialValue: preferences.compositionTextDisplay,
                decoration: const InputDecoration(
                  labelText: 'Checklist and subtask text',
                ),
                items: const [
                  DropdownMenuItem(
                    value: CompositionTextDisplay.full,
                    child: Text('Show full text'),
                  ),
                  DropdownMenuItem(
                    value: CompositionTextDisplay.compact,
                    child: Text('Compact (two lines, expandable)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    save(preferences.copyWith(compositionTextDisplay: value));
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Undo setting (Ctrl+Z)',
            onPressed: history.canUndo ? () => travel(false) : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo setting (Ctrl+Shift+Z)',
            onPressed: history.canRedo ? () => travel(true) : null,
            icon: const Icon(Icons.redo),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
