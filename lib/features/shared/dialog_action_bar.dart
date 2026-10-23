import 'package:flutter/material.dart';

/// Keeps dialog actions reachable when the window or text scale is narrow.
class DialogActionBar extends StatelessWidget {
  const DialogActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => OverflowBar(
    alignment: MainAxisAlignment.end,
    overflowAlignment: OverflowBarAlignment.end,
    spacing: 8,
    overflowSpacing: 8,
    children: children,
  );
}
