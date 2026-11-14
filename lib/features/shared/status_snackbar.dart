import 'package:flutter/material.dart';

import 'app_spacing.dart';

enum NotificationType { success, info, warning, error }

Duration notificationDuration(NotificationType type) => switch (type) {
  NotificationType.success => const Duration(seconds: 3),
  NotificationType.info => const Duration(seconds: 4),
  NotificationType.warning => const Duration(seconds: 5),
  NotificationType.error => const Duration(seconds: 7),
};

Duration statusReadingDuration(
  BuildContext context,
  String message,
  NotificationType type,
) {
  final base = notificationDuration(type).inSeconds;
  final length = message.runes.length;
  final readingSeconds = length <= 140
      ? base
      : (length / 12).ceil().clamp(base, 30);
  return Duration(
    seconds: MediaQuery.accessibleNavigationOf(context)
        ? readingSeconds * 2
        : readingSeconds,
  );
}

/// Short confirmation only; required decisions keep their own actionable UI.
SnackBar transientStatusSnackBar(
  BuildContext context,
  String message, {
  NotificationType type = NotificationType.info,
  Key? key,
}) {
  final theme = Theme.of(context);
  final isError = type == NotificationType.error;
  final isWarning = type == NotificationType.warning;

  return SnackBar(
    key: key,
    persist: false,
    showCloseIcon: isError || isWarning,
    closeIconColor: isError
        ? theme.colorScheme.onErrorContainer
        : isWarning
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSurface,
    behavior: SnackBarBehavior.floating,
    backgroundColor: isError
        ? theme.colorScheme.errorContainer
        : isWarning
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.surfaceContainerHigh,
    elevation: 2,
    margin: const EdgeInsets.all(AppSpacing.related),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: isError
            ? theme.colorScheme.error
            : isWarning
            ? theme.colorScheme.tertiary
            : theme.colorScheme.outlineVariant,
      ),
    ),
    duration: statusReadingDuration(context, message, type),
    content: Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: isError
            ? theme.colorScheme.onErrorContainer
            : isWarning
            ? theme.colorScheme.onTertiaryContainer
            : theme.colorScheme.onSurface,
      ),
    ),
  );
}

/// Replaces stale temporary feedback rather than queueing messages after it.
void showTransientStatus(
  BuildContext context,
  String message, {
  NotificationType type = NotificationType.info,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(transientStatusSnackBar(context, message, type: type));
}
