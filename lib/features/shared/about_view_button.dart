import 'package:flutter/material.dart';

class AboutViewButton extends StatefulWidget {
  const AboutViewButton({super.key, required this.description});

  final String description;

  @override
  State<AboutViewButton> createState() => _AboutViewButtonState();
}

class _AboutViewButtonState extends State<AboutViewButton> {
  final _triggerFocus = FocusNode();

  @override
  void dispose() {
    _triggerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    childFocusNode: _triggerFocus,
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(
        Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
    ),
    menuChildren: [
      Focus(
        autofocus: true,
        skipTraversal: true,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(widget.description),
          ),
        ),
      ),
    ],
    builder: (context, menu, child) => IconButton(
      key: const ValueKey('view-info-button'),
      focusNode: _triggerFocus,
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
