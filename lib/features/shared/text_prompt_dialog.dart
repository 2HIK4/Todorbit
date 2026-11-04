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
    this.help,
    this.save,
  });

  final String title, initial, submitLabel;
  final String? label, help;
  final int? maxLength;
  final Future<void> Function(String value)? save;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final input = TextEditingController(text: widget.initial);
  bool busy = false;
  String? error;

  Future<void> _submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save?.call(input.text);
      if (mounted) Navigator.pop(context, input.text);
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is ArgumentError
              ? '${failure.message}'
              : '$failure',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: SizedBox(
        width: widget.help == null ? null : 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.help != null) ...[
              Text(widget.help!),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: input,
              enabled: !busy,
              autofocus: true,
              maxLength: widget.maxLength,
              decoration: InputDecoration(labelText: widget.label),
              onFieldSubmitted: (_) => _submit(),
            ),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    ),
  );
}
