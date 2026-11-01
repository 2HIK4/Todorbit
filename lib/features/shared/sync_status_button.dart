import 'package:flutter/material.dart';

class SyncStatusButton extends StatelessWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('sync-status-button'),
    tooltip: 'Sync — coming soon',
    icon: const Icon(Icons.cloud_sync_outlined),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Sync is coming soon'),
        content: const SizedBox(
          width: 360,
          child: Text(
            'Google Drive sync is not available in this build. '
            'Automatic syncing, device pairing and conflict resolution '
            'will arrive in a future update.\n\n'
            'For now, use Backups & Cloud to transfer a snapshot '
            'between your devices.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}
