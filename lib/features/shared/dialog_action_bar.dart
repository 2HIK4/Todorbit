import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// Keeps dialog actions reachable when the window or text scale is narrow.
class DialogActionBar extends StatelessWidget {
  const DialogActionBar({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.end,
  });

  final List<Widget> children;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => OverflowBar(
    alignment: alignment,
    overflowAlignment: OverflowBarAlignment.end,
    spacing: AppSpacing.gap,
    overflowSpacing: AppSpacing.gap,
    children: children,
  );
}
