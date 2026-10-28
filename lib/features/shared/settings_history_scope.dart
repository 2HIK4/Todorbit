import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lets the focused EditableText retain its platform undo/redo bindings.
class SettingsHistoryScope extends StatelessWidget {
  const SettingsHistoryScope({
    super.key,
    required this.undo,
    required this.redo,
    required this.child,
  });
  final VoidCallback undo, redo;
  final Widget child;
  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent ||
          !HardwareKeyboard.instance.isControlPressed) {
        return KeyEventResult.ignored;
      }
      final editing = FocusManager.instance.primaryFocus?.context;
      if (editing != null &&
          (editing.widget is EditableText ||
              editing.findAncestorWidgetOfExactType<EditableText>() != null)) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        HardwareKeyboard.instance.isShiftPressed ? redo() : undo();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyY) {
        redo();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );
}
