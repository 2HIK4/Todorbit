import 'package:flutter/material.dart';

/// Keeps text editing alive through the dialog's closing animation.
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    this.initial = '',
    this.label,
    this.maxLength = 60,
    this.submitLabel = 'Continue',
  });

  final String title, initial, submitLabel;
  final String? label;
  final int maxLength;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final input = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: TextField(
      controller: input,
      autofocus: true,
      maxLength: widget.maxLength,
      decoration: InputDecoration(labelText: widget.label),
      onSubmitted: (_) => Navigator.pop(context, input.text),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, input.text),
        child: Text(widget.submitLabel),
      ),
    ],
  );
}
