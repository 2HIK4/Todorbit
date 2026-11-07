import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// Short confirmation only; required decisions keep their own actionable UI.
SnackBar transientStatusSnackBar(
  BuildContext context,
  String message, {
  Key? key,
}) {
  final theme = Theme.of(context);
  return SnackBar(
    key: key,
    persist: false,
    showCloseIcon: false,
    behavior: SnackBarBehavior.floating,
    backgroundColor: theme.colorScheme.surfaceContainerHigh,
    elevation: 2,
    margin: const EdgeInsets.all(AppSpacing.related),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    ),
    duration: const Duration(seconds: 4),
    content: Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    ),
  );
}
