import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

import 'settings_section.dart';

/// A keyboard-accessible color picker that fits short desktop windows.
class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    super.key,
    required this.title,
    required this.initialColor,
    this.defaultColor,
  });

  final String title;
  final Color initialColor;
  final Color? defaultColor;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color preview = widget.initialColor;
  late final hex = TextEditingController(text: _hex(preview));
  bool valid = true;

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Live color preview ${_hex(preview)}',
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: preview,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
          ColorPicker(
            color: preview,
            onColorChanged: (color) => setState(() {
              preview = color;
              valid = true;
              hex.text = _hex(color);
            }),
            pickersEnabled: const {
              ColorPickerType.primary: false,
              ColorPickerType.accent: false,
              ColorPickerType.bw: false,
              ColorPickerType.custom: false,
              ColorPickerType.customSecondary: false,
              ColorPickerType.wheel: true,
            },
            enableShadesSelection: false,
            wheelDiameter: 190,
            wheelWidth: 18,
            showColorCode: false,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          TextField(
            controller: hex,
            maxLength: 7,
            decoration: InputDecoration(
              labelText: 'HEX color',
              hintText: '#RRGGBB',
              errorText: valid ? null : 'Enter a six-digit HEX color',
            ),
            onChanged: (value) => setState(() {
              valid = RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value);
              if (valid) {
                preview = Color(
                  int.parse('FF${value.substring(1)}', radix: 16),
                );
              }
            }),
            onSubmitted: (_) {
              if (valid) Navigator.pop(context, preview);
            },
          ),
          const SizedBox(height: 8),
          const SettingsHelperText(
            'Choose a color with the wheel or enter its HEX value.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (widget.defaultColor != null)
        TextButton(
          onPressed: () => Navigator.pop(context, widget.defaultColor),
          child: const Text('Reset'),
        ),
      FilledButton(
        onPressed: valid ? () => Navigator.pop(context, preview) : null,
        child: const Text('Confirm'),
      ),
    ],
  );
}
