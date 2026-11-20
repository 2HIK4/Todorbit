import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/time_tracking.dart';
import '../shared/status_snackbar.dart';

// One intent across both shells and focus controls, including rapid taps while
// the confirmation or the repository transaction is still pending.
final _pending = Expando<bool>();

Future<void> openTaskTimer(
  BuildContext context,
  AppController controller,
  String taskId, {
  required ValueChanged<String> open,
}) async {
  if (_pending[controller] == true) return;
  _pending[controller] = true;
  try {
    await controller.refresh();
    if (!context.mounted) return;
    final existing = controller.activeTimer;
    if (existing != null && existing.taskId != taskId) {
      final title =
          controller.tasks
              .where((task) => task.id == existing.taskId)
              .firstOrNull
              ?.title ??
          'another task';
      if (!context.mounted) return;
      final canSwitch =
          existing.canControl && !existing.needsReview(DateTime.now());
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('A task timer is already active'),
          content: Text(
            '$title is ${existing.state == TimerState.paused ? 'paused' : 'running'}. '
            'Switching stops that timer and keeps all recorded work. '
            'Task status and planned sessions stay unchanged.'
            '${canSwitch ? '' : ' Open the existing timer to review it on its controlling device.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'existing'),
              child: const Text('Open existing timer'),
            ),
            if (canSwitch)
              FilledButton(
                onPressed: () => Navigator.pop(context, 'switch'),
                child: const Text('Stop and switch'),
              ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      if (choice == 'existing') {
        if (existing.taskId != null) open(existing.taskId!);
        return;
      }
      await controller.switchTaskTimer(existing, taskId);
    } else if (existing == null) {
      await controller.enterTaskTimer(taskId);
    }
    if (context.mounted) open(taskId);
  } on StateError {
    await controller.refresh();
    if (context.mounted) {
      showTransientStatus(
        context,
        'The timer changed. Open the active timer to continue.',
      );
    }
  } catch (_) {
    if (context.mounted) {
      showTransientStatus(
        context,
        'Could not open the timer. Please try again.',
      );
    }
  } finally {
    _pending[controller] = false;
  }
}
