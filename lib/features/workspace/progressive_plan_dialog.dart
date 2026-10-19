import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';

class ProgressivePlanDialog extends ConsumerStatefulWidget {
  const ProgressivePlanDialog({super.key, required this.task});
  final LifeTask task;

  @override
  ConsumerState<ProgressivePlanDialog> createState() =>
      _ProgressivePlanDialogState();
}

class _ProgressivePlanDialogState extends ConsumerState<ProgressivePlanDialog> {
  final steps = TextEditingController();
  bool repeatAtEnd = false;
  List<String> savedSteps = [];
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await ref
        .read(appControllerProvider)
        .progressivePlan(widget.task.id);
    if (!mounted) return;
    steps.text = plan?.steps.join('\n') ?? '';
    savedSteps = plan?.steps ?? [];
    setState(() {
      repeatAtEnd = plan?.repeatAtEnd ?? false;
      loading = false;
    });
  }

  @override
  void dispose() {
    steps.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final lines = steps.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one activity.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(appControllerProvider)
          .configureProgressivePlan(
            widget.task.id,
            lines,
            repeatAtEnd: repeatAtEnd,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save plan: $error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = ref
        .watch(appControllerProvider)
        .progressiveAssignments[widget.task.id];
    return AlertDialog(
      title: const Text('Recurring task plan'),
      content: SizedBox(
        width: 520,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'One activity per line. Order the lines to match successive scheduled occurrences. Changes update future untouched occurrences; past assignments stay as recorded.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: steps,
                      minLines: 5,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: 'Ordered activities',
                        hintText: 'Watch lessons 1–10\nRevise lessons 1–10',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repeat after final activity'),
                      subtitle: const Text(
                        'When off, later occurrences show that the plan has finished. Add more activities to continue.',
                      ),
                      value: repeatAtEnd,
                      onChanged: (value) => setState(() => repeatAtEnd = value),
                    ),
                    if (assignment != null) ...[
                      const Divider(),
                      Text(
                        'This occurrence: ${assignment.title ?? 'Plan finished'}',
                      ),
                      if (assignment.manual) const Text('Manually assigned'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final choices = savedSteps;
                          final selected = await showDialog<int>(
                            context: context,
                            builder: (context) => SimpleDialog(
                              title: const Text('Assign this occurrence'),
                              children: [
                                for (var i = 0; i < choices.length; i++)
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, i),
                                    child: Text('${i + 1}. ${choices[i]}'),
                                  ),
                              ],
                            ),
                          );
                          if (selected == null || !context.mounted) return;
                          try {
                            await ref
                                .read(appControllerProvider)
                                .reassignProgressiveStep(
                                  widget.task.id,
                                  selected,
                                );
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$error')));
                            }
                          }
                        },
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Assign a step to this occurrence'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Carry this activity forward'),
                        subtitle: const Text(
                          'The next scheduled occurrence repeats this step. Use for unfinished or skipped work.',
                        ),
                        value: assignment.carryForward,
                        onChanged: (value) async {
                          try {
                            await ref
                                .read(appControllerProvider)
                                .setProgressiveCarry(widget.task.id, value);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$error')));
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: loading || saving ? null : _save,
          child: const Text('Save plan'),
        ),
      ],
    );
  }
}
