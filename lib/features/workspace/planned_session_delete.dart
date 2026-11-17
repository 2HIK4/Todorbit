import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../shared/status_snackbar.dart';

class PlannedSessionDelete extends ConsumerStatefulWidget {
  const PlannedSessionDelete({super.key, required this.session});
  final WorkSession session;
  @override
  ConsumerState<PlannedSessionDelete> createState() =>
      _PlannedSessionDeleteState();
}

class _PlannedSessionDeleteState extends ConsumerState<PlannedSessionDelete> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Delete planned session',
    icon: const Icon(Icons.delete_outline),
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete planned session?'),
                  content: const Text(
                    'Move this plan to Trash? You can restore it there. The task and recorded work are kept.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !mounted) return;
              final controller = ref.read(appControllerProvider);
              await controller.repository.deletePlannedSession(widget.session);
              await controller.refresh();
            } catch (_) {
              if (context.mounted) {
                showTransientStatus(
                  context,
                  'The session changed or could not be deleted. Reopen it and try again.',
                );
              }
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
  );
}
