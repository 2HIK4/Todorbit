import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/inline_spelling_controller.dart';

Future<String?> editChecklistItem(
  BuildContext context, {
  required String title,
  required String initialValue,
  required bool spellCheckEnabled,
}) => showDialog<String>(
  context: context,
  builder: (_) => _ChecklistItemEditorDialog(
    title: title,
    initialValue: initialValue,
    spellCheckEnabled: spellCheckEnabled,
  ),
);

class _ChecklistItemEditorDialog extends StatefulWidget {
  const _ChecklistItemEditorDialog({
    required this.title,
    required this.initialValue,
    required this.spellCheckEnabled,
  });
  final String title;
  final String initialValue;
  final bool spellCheckEnabled;

  @override
  State<_ChecklistItemEditorDialog> createState() =>
      _ChecklistItemEditorDialogState();
}

class _ChecklistItemEditorDialogState
    extends State<_ChecklistItemEditorDialog> {
  late final TextEditingController field = InlineSpellingController(
    text: widget.initialValue,
    enabled: widget.spellCheckEnabled,
  );

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        key: const ValueKey('checklist-dialog-surface'),
        width: math.min(440, viewport.width - 32),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextField(
                controller: field,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.pop(context, field.text.trim()),
                decoration: const InputDecoration(labelText: 'Activity'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, field.text.trim()),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
