import 'package:flutter/material.dart';

/// Keeps platform Back and the visible close action on the same draft boundary.
class UnsavedEditorGuard extends StatefulWidget {
  const UnsavedEditorGuard({
    super.key,
    required this.enabled,
    required this.dirty,
    required this.busy,
    required this.onClose,
    required this.child,
  });
  final bool enabled, dirty, busy;
  final VoidCallback onClose;
  final Widget child;
  @override
  State<UnsavedEditorGuard> createState() => UnsavedEditorGuardState();
}

class UnsavedEditorGuardState extends State<UnsavedEditorGuard> {
  bool permitting = false, confirming = false;
  Future<void> close({bool saved = false}) async {
    if (confirming || widget.busy && !saved) return;
    if (!widget.enabled) {
      widget.onClose();
      return;
    }
    if (!saved && widget.dirty) {
      confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text('Your changes have not been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      confirming = false;
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
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
