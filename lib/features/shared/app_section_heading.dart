import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// Page title and primary action, stacked when space or text scale requires it.
class AppPageHeading extends StatelessWidget {
  const AppPageHeading({
    super.key,
    required this.title,
    required this.detail,
    required this.action,
  });

  final String title;
  final String detail;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: text.headlineLarge)),
        const SizedBox(height: AppSpacing.small),
        Text(detail, style: text.bodySmall),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        if (constraints.maxWidth < AppLayout.workspaceMinWidth * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: AppSpacing.gap),
              action,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.related),
            action,
          ],
        );
      },
    );
  }
}

/// A list section heading with an optional supporting value.
class AppSectionHeading extends StatelessWidget {
  const AppSectionHeading(this.title, {super.key, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.gap),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.related,
        runSpacing: AppSpacing.small,
        children: [
          Semantics(header: true, child: Text(title, style: text.titleSmall)),
          if (detail != null) Text(detail!, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Empty list feedback. Supply an action when the parent has no primary action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.action,
  });

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.content,
        vertical: AppSpacing.section,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.small),
            Text(message!, style: text.bodyMedium),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.related),
            action!,
          ],
        ],
      ),
    );
  }
}
