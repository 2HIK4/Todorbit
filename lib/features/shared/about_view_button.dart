import 'package:flutter/material.dart';

class AboutViewButton extends StatelessWidget {
  const AboutViewButton({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(
        Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
    ),
    menuChildren: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(description),
        ),
      ),
    ],
    builder: (context, menu, child) => IconButton(
      key: const ValueKey('view-info-button'),
      tooltip: 'About this view',
      style: IconButton.styleFrom(
        overlayColor: Theme.of(context).colorScheme.primary
            .withValues(alpha: 0.08),
      ),
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      icon: const Icon(Icons.info_outline),
    ),
  );
}
