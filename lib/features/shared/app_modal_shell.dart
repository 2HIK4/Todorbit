import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'app_spacing.dart';

/// A responsive, accessible modal shell that bounds width, height, and respects
/// keyboard insets across desktop and mobile form factors.
class AppModalShell extends StatelessWidget {
  const AppModalShell({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.dialogDefaultWidth,
    this.maxHeight = AppLayout.dialogDefaultHeight,
    this.minWidth = AppLayout.dialogMinWidth,
    this.minHeight = 280.0,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final double minWidth;
  final double minHeight;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom - 48;
    final width = math.min(maxWidth, math.max(minWidth, media.size.width - 32));
    final height = math.min(maxHeight, math.max(minHeight, availableHeight));

    return Dialog(
      clipBehavior: clipBehavior,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: width,
        height: height,
        child: child,
      ),
    );
  }
}

/// Convenience helper to present an animated responsive modal dialog.
Future<T?> showAppModal<T>({
  required BuildContext context,
  required Widget Function(BuildContext dialogContext) builder,
  double maxWidth = AppLayout.dialogDefaultWidth,
  double maxHeight = AppLayout.dialogDefaultHeight,
  double minWidth = AppLayout.dialogMinWidth,
  double minHeight = 280.0,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    animationStyle: AppMotion.style(context),
    builder: (dialogContext) => AppModalShell(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      minWidth: minWidth,
      minHeight: minHeight,
      child: builder(dialogContext),
    ),
  );
}
