import 'app_motion.dart';

import 'package:flutter/material.dart';

enum UnsavedEditorDecision { save, discard }

Future<UnsavedEditorDecision?> askUnsavedEditorDecision(
  BuildContext context, {
  required bool canSave,
  String message = 'Your changes have not been saved.',
}) => showDialog<UnsavedEditorDecision>(
  context: context,
  animationStyle: AppMotion.style(context),
  builder: (context) => AlertDialog(
    title: const Text('Discard unsaved changes?'),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Keep editing'),
      ),
      if (canSave)
        TextButton(
          onPressed: () =>
              Navigator.pop(context, UnsavedEditorDecision.discard),
          child: const Text('Discard changes'),
        )
      else
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, UnsavedEditorDecision.discard),
          child: const Text('Discard changes'),
        ),
      if (canSave)
        FilledButton(
          onPressed: () => Navigator.pop(context, UnsavedEditorDecision.save),
          child: const Text('Save'),
        ),
    ],
  ),
);

/// Keeps platform Back and the visible close action on the same draft boundary.
class UnsavedEditorGuard extends StatefulWidget {
  const UnsavedEditorGuard({
    super.key,
    required this.enabled,
    required this.dirty,
    required this.busy,
    required this.onClose,
    this.onSave,
    required this.child,
  });
  final bool enabled, dirty, busy;
  final VoidCallback onClose;
  final Future<bool> Function()? onSave;
  final Widget child;
  @override
  State<UnsavedEditorGuard> createState() => UnsavedEditorGuardState();
}

class UnsavedEditorGuardState extends State<UnsavedEditorGuard> {
  bool permitting = false, confirming = false;
  Future<bool> confirmLeave({bool? dirty}) async {
    if (confirming || widget.busy) return false;
    if (!widget.enabled || !(dirty ?? widget.dirty)) return true;
    confirming = true;
    try {
      final decision = await askUnsavedEditorDecision(
        context,
        canSave: widget.onSave != null,
      );
      if (!mounted) return false;
      return switch (decision) {
        UnsavedEditorDecision.discard => true,
        UnsavedEditorDecision.save => await widget.onSave!(),
        null => false,
      };
    } finally {
      confirming = false;
    }
  }

  Future<void> close({bool saved = false}) async {
    if (permitting || confirming || (!saved && !await confirmLeave())) return;
    if (!mounted) return;
    if (!widget.enabled) {
      widget.onClose();
      return;
    }
    setState(() => permitting = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.enabled || permitting || !widget.dirty && !widget.busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: widget.child,
  );
}
