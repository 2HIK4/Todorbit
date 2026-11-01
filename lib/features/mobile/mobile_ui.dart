import 'package:flutter/material.dart';

import '../shared/app_spacing.dart';

/// Shared section rhythm for the mobile workspace and settings.
class MobileSectionTitle extends StatelessWidget {
  const MobileSectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.small,
      AppSpacing.section,
      AppSpacing.small,
      AppSpacing.related,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}
