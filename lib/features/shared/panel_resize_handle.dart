import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_spacing.dart';

/// Keyboard and pointer separator for a trailing workspace pane.
class PanelResizeHandle extends StatefulWidget {
  const PanelResizeHandle({
    super.key,
    required this.width,
    required this.maxWidth,
    required this.onDrag,
    required this.onCommit,
    required this.onAdjust,
  });

  final double width;
  final double maxWidth;
  final ValueChanged<double> onDrag;
  final VoidCallback onCommit;
  final ValueChanged<double> onAdjust;

  @override
  State<PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<PanelResizeHandle> {
  bool highlighted = false;

  @override
  Widget build(BuildContext context) {
    const step = AppSpacing.content;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final scheme = Theme.of(context).colorScheme;
    final increased = math.min(widget.width + step, widget.maxWidth);
    final decreased = math.max(widget.width - step, AppLayout.panelMinWidth);
    String describe(double width) => '${width.round()} logical pixels';
    return Semantics(
      label: 'Task panel width',
      value: describe(widget.width),
      increasedValue: increased > widget.width ? describe(increased) : null,
      decreasedValue: decreased < widget.width ? describe(decreased) : null,
      onIncrease: increased > widget.width ? () => widget.onAdjust(step) : null,
      onDecrease: decreased < widget.width
          ? () => widget.onAdjust(-step)
          : null,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              widget.onAdjust(rtl ? -step : step),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              widget.onAdjust(rtl ? step : -step),
        },
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.resizeColumn,
          onShowFocusHighlight: (value) => setState(() => highlighted = value),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) =>
                widget.onDrag(details.delta.dx * (rtl ? 1 : -1)),
            onHorizontalDragEnd: (_) => widget.onCommit(),
            onHorizontalDragCancel: widget.onCommit,
            child: Tooltip(
              message: 'Resize task panel',
              child: SizedBox(
                width: AppLayout.panelResizeHandle,
                child: Center(
                  child: VerticalDivider(
                    width: AppSpacing.small,
                    thickness: highlighted ? 2 : 1,
                    color: highlighted ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
