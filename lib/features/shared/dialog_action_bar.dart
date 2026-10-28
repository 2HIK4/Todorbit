import 'package:flutter/material.dart';

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
    spacing: 8,
    overflowSpacing: 8,
    children: children,
  );
}
