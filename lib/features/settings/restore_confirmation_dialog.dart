import 'package:flutter/material.dart';

import '../shared/settings_section.dart';
import '../shared/status_notice.dart';

class RestoreConfirmationDialog extends StatelessWidget {
  const RestoreConfirmationDialog({
    super.key,
    required this.backupLabel,
    required this.summary,
    required this.localWarning,
    required this.details,
  });

  final String backupLabel, summary, localWarning, details;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Replace this local profile?'),
    scrollable: true,
    content: SizedBox(
      width: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(backupLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(summary),
          const SettingsHelperText(
            'Counts include archived and deleted records retained for recovery.',
          ),
          StatusNotice(
            title: 'Before you restore',
            message: localWarning,
            icon: Icons.warning_amber_outlined,
          ),
          const Text(
            'Replaces all database records and included personalization on the next launch. Tasks are not merged.',
          ),
          const SizedBox(height: 12),
          const SettingsHelperText(
            'A verified Before Restore database backup and a separate settings JSON are saved first. Credentials and privacy controls stay on this device.',
          ),
          const SizedBox(height: 12),
          const SettingsHelperText(
            'Check the backup date: it may be older than your local work. Linked external files are not included and may need relinking.',
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: 'Restore details',
            children: [
              SelectableText(
                details,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Confirm replacement'),
      ),
    ],
  );
}
