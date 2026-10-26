import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A form select whose menu is anchored below the field instead of centering
/// the selected item over it, as [DropdownButtonFormField] does.
class AnchoredSelectField<T> extends FormField<T> {
  AnchoredSelectField({
    super.key,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    super.initialValue,
    InputDecoration decoration = const InputDecoration(),
    bool isExpanded = false,
    String? externalLabel,
  }) : super(
         builder: (field) => _AnchoredSelectBody<T>(
           field: field,
           items: items,
           onChanged: onChanged,
           decoration: decoration,
           isExpanded: isExpanded,
           externalLabel: externalLabel,
         ),
       );
}

class _AnchoredSelectBody<T> extends StatefulWidget {
  const _AnchoredSelectBody({
    required this.field,
    required this.items,
    required this.onChanged,
    required this.decoration,
    required this.isExpanded,
    required this.externalLabel,
  });

  final FormFieldState<T> field;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final bool isExpanded;
  final String? externalLabel;

  @override
  State<_AnchoredSelectBody<T>> createState() => _AnchoredSelectBodyState<T>();
}

class _AnchoredSelectBodyState<T> extends State<_AnchoredSelectBody<T>> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _triggerFocusNode = FocusNode();
  bool _triggerFocused = false;
  late List<FocusNode> _itemFocusNodes = _newFocusNodes();

  List<FocusNode> _newFocusNodes() => [
    for (var i = 0; i < widget.items.length; i++) FocusNode(),
  ];

  @override
  void didUpdateWidget(covariant _AnchoredSelectBody<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      for (final node in _itemFocusNodes) {
        node.dispose();
      }
      _itemFocusNodes = _newFocusNodes();
    }
  }

  @override
  void dispose() {
    for (final node in _itemFocusNodes) {
      node.dispose();
    }
    _scrollController.dispose();
    _triggerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onChanged != null && widget.items.isNotEmpty;
    final selected = widget.items
        .where((item) => item.value == widget.field.value)
        .firstOrNull;
    final visible = selected?.child ?? const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context);
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : math.min(viewport.width - 32, 320.0);
        return MenuAnchor(
          childFocusNode: _triggerFocusNode,
          style: MenuStyle(
            minimumSize: WidgetStatePropertyAll(Size(width, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(width, math.min(320, viewport.height - 32)),
            ),
            backgroundColor: WidgetStatePropertyAll(
              theme.colorScheme.surfaceContainerHigh,
            ),
          ),
          menuChildren: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.min(312, viewport.height - 40),
                minWidth: width,
                maxWidth: width,
              ),
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent || _itemFocusNodes.isEmpty) {
                    return KeyEventResult.ignored;
                  }
                  final direction = switch (event.logicalKey) {
                    LogicalKeyboardKey.arrowDown => 1,
                    LogicalKeyboardKey.arrowUp => -1,
                    _ => 0,
                  };
                  if (direction == 0) return KeyEventResult.ignored;
                  final current = _itemFocusNodes.indexWhere(
                    (item) => item.hasFocus,
                  );
                  var next = current + direction;
                  while (next >= 0 && next < widget.items.length) {
                    if (widget.items[next].enabled) {
                      final target = _itemFocusNodes[next];
                      target.requestFocus();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final targetContext = target.context;
                        if (mounted && targetContext != null) {
                          Scrollable.ensureVisible(targetContext);
                        }
                      });
                      break;
                    }
                    next += direction;
                  }
                  return KeyEventResult.handled;
                },
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: widget.items.length > 6,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (
                          var index = 0;
                          index < widget.items.length;
                          index++
                        )
                          MenuItemButton(
                            focusNode: _itemFocusNodes[index],
                            autofocus:
                                index ==
                                widget.items.indexWhere((item) => item.enabled),
                            onPressed: enabled && widget.items[index].enabled
                                ? () {
                                    widget.field.didChange(
                                      widget.items[index].value,
                                    );
                                    widget.onChanged!(
                                      widget.items[index].value,
                                    );
                                  }
                                : null,
                            leadingIcon:
                                widget.items[index].value == widget.field.value
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  )
                                : const SizedBox(width: 18),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: DefaultTextStyle.merge(
                                overflow: TextOverflow.ellipsis,
                                child: widget.items[index].child,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          builder: (context, controller, child) {
            final trigger = Semantics(
              button: true,
              expanded: controller.isOpen,
              enabled: enabled,
              child: InkWell(
                focusNode: _triggerFocusNode,
                onFocusChange: (focused) =>
                    setState(() => _triggerFocused = focused),
                onTap: enabled
                    ? () => controller.isOpen
                          ? controller.close()
                          : controller.open()
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  isEmpty: false,
                  isFocused: enabled && (_triggerFocused || controller.isOpen),
                  decoration: widget.decoration.copyWith(
                    enabled: enabled,
                    errorText: widget.field.errorText,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: SizedBox(
                    width: widget.isExpanded ? double.infinity : null,
                    child: DefaultTextStyle.merge(
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      child: visible,
                    ),
                  ),
                ),
              ),
            );
            if (widget.externalLabel == null) return trigger;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.externalLabel!, style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                trigger,
              ],
            );
          },
        );
      },
    );
  }
}
