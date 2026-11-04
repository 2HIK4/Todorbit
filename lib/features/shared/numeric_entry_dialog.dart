import 'package:flutter/material.dart';

import 'unsaved_editor_guard.dart';

/// Edits a numeric entry without dropping the draft before persistence succeeds.
class NumericEntryDialog extends StatefulWidget {
  const NumericEntryDialog({
    super.key,
    required this.title,
    required this.label,
    required this.submitLabel,
    required this.validate,
    required this.save,
    this.initialValue = '',
    this.initialNotes = '',
    this.help,
    this.signed = false,
  });

  final String title, label, submitLabel, initialValue, initialNotes;
  final String? help;
  final bool signed;
  final String? Function(double? value) validate;
  final Future<void> Function(double value, String notes) save;

  @override
  State<NumericEntryDialog> createState() => _NumericEntryDialogState();
}

class _NumericEntryDialogState extends State<NumericEntryDialog> {
  final guard = GlobalKey<UnsavedEditorGuardState>();
  final form = GlobalKey<FormState>();
  late final value = TextEditingController(text: widget.initialValue)
    ..addListener(_changed);
  late final notes = TextEditingController(text: widget.initialNotes)
    ..addListener(_changed);
  bool busy = false;
  String? error;

  void _changed() => setState(() {});

  @override
  void dispose() {
    value.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save(double.parse(value.text.trim()), notes.text);
      if (mounted) await guard.currentState?.close(saved: true);
    } catch (failure) {
      if (mounted) setState(() => error = 'Entry was not saved: $failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedEditorGuard(
    key: guard,
    enabled: true,
    dirty:
        value.text != widget.initialValue || notes.text != widget.initialNotes,
    busy: busy,
    onClose: () => Navigator.pop(context),
    child: AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.help != null) Text(widget.help!),
            TextFormField(
              key: const ValueKey('numeric-entry-value'),
              controller: value,
              enabled: !busy,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: widget.signed,
              ),
              decoration: InputDecoration(labelText: widget.label),
              validator: (text) =>
                  widget.validate(double.tryParse(text?.trim() ?? '')),
            ),
            TextFormField(
              controller: notes,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Reason or note'),
            ),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => guard.currentState?.close(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: Text(widget.submitLabel),
        ),
      ],
    ),
  );
}
