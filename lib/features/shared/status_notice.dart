import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// A readable inline state, with an icon and label as well as color.
class StatusNotice extends StatelessWidget {
  const StatusNotice({
    super.key,
    required this.title,
    required this.message,
    this.error = false,
    this.icon = Icons.info_outline,
  });

  final String title, message;
  final bool error;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.gap),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(
              color: error
                  ? theme.colorScheme.error
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.content),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  error ? Icons.error_outline : icon,
                  color: error
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(message, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
