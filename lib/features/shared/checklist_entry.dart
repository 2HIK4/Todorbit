import 'package:flutter/material.dart';

// Draft and saved checklists use the same label clearance and action spacing.
class ChecklistEntry extends StatelessWidget {
  const ChecklistEntry({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.onAdd,
    required this.tooltip,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: controller,
            decoration: const InputDecoration(labelText: 'New checklist item'),
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: tooltip,
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}
