import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

const eventColors = <(String, int)>[
  ('Indigo', 0xFF5365B5),
  ('Purple', 0xFF7E57C2),
  ('Teal', 0xFF00897B),
  ('Amber', 0xFFD17A22),
  ('Rose', 0xFFB65372),
  ('Ocean', 0xFF3376A3),
  ('Olive', 0xFF6A8A43),
  ('Coral', 0xFFB45A44),
];

String eventColorLabel(int? value) {
  if (value == null) return 'Inherited default';
  for (final color in eventColors) {
    if (color.$2 == value) return color.$1;
  }
  return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Future<int?> chooseEventColor(BuildContext context, int initial) =>
    showDialog<int>(
      context: context,
      builder: (_) => _EventColorDialog(initial: initial),
    );

class _EventColorDialog extends StatefulWidget {
  const _EventColorDialog({required this.initial});

  final int initial;

  @override
  State<_EventColorDialog> createState() => _EventColorDialogState();
}

class _EventColorDialogState extends State<_EventColorDialog> {
  late Color preview;
  late final TextEditingController hex;
  var valid = true;

  @override
  void initState() {
    super.initState();
    preview = Color(widget.initial);
    hex = TextEditingController(
      text:
          '#${(widget.initial & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    );
  }

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Custom event color'),
    content: SizedBox(
      width: 350,
      height: 385,
      child: Column(
        children: [
          Container(
            height: 38,
            width: double.infinity,
            decoration: BoxDecoration(
              color: preview,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: ColorPicker(
                color: preview,
                onColorChanged: (color) => setState(() {
                  preview = color;
                  valid = true;
                  hex.text =
                      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
                }),
                pickersEnabled: const {ColorPickerType.wheel: true},
                enableShadesSelection: false,
                wheelDiameter: 190,
                wheelWidth: 18,
                showColorCode: false,
              ),
            ),
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
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: valid
            ? () => Navigator.pop(context, preview.toARGB32())
            : null,
        child: const Text('Use color'),
      ),
    ],
  );
}
