import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/hotkeys.dart';
import '../shared/settings_section.dart';
import '../shared/text_prompt_dialog.dart';

class HotkeysDialog extends ConsumerStatefulWidget {
  const HotkeysDialog({super.key});

  @override
  ConsumerState<HotkeysDialog> createState() => _HotkeysDialogState();
}

class _HotkeysDialogState extends ConsumerState<HotkeysDialog> {
  final captureFocus = FocusNode();
  String query = '';
  HotkeyAction? recording;
  HotkeyBinding? pending;
  String? warning;

  @override
  void dispose() {
    captureFocus.dispose();
    super.dispose();
  }

  void _error(Object failure) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$failure')));
  }

  Future<void> _update(HotkeyPreferences next) async {
    try {
      await ref.read(appControllerProvider).setHotkeys(next);
      if (mounted) {
        setState(() {
          recording = null;
          pending = null;
          warning = null;
        });
      }
    } catch (failure) {
      _error(failure);
    }
  }

  Future<String?> _nameDialog(String title, String initial) async {
    return showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: title,
        initial: initial,
        label: 'Preset name',
        maxLength: 40,
        submitLabel: 'Save',
      ),
    );
  }

  KeyEventResult _capture(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final binding = HotkeyBinding.fromKeyEvent(event);
    setState(() {
      pending = binding;
      warning = binding == null
          ? 'Use Ctrl with a letter or digit. Windows and editing shortcuts are reserved.'
          : ref
                .read(appControllerProvider)
                .hotkeys
                .bindings
                .entries
                .any(
                  (entry) => entry.key != recording && entry.value == binding,
                )
          ? '${binding.display} is already assigned.'
          : null;
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final hotkeys = controller.hotkeys;
    final actions = HotkeyAction.values
        .where(
          (action) => '${action.group} ${action.label}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return AlertDialog(
      title: const Text('Hotkeys'),
      content: SizedBox(
        width: 600,
        height: 560,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 4,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : constraints.maxWidth - 208,
                    child: AnchoredSelectField<String>(
                      key: ValueKey(hotkeys.activePreset),
                      initialValue: hotkeys.activePreset,
                      decoration: const InputDecoration(labelText: 'Preset'),
                      items: [
                        for (final name in hotkeys.presets.keys)
                          DropdownMenuItem(value: name, child: Text(name)),
                      ],
                      onChanged: (name) {
                        if (name != null) _update(hotkeys.select(name));
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Save as new preset',
                    icon: const Icon(Icons.save_as_outlined),
                    onPressed: () async {
                      final name = await _nameDialog(
                        'Save shortcut preset',
                        '',
                      );
                      if (name == null) return;
                      try {
                        await _update(hotkeys.saveAs(name));
                      } catch (failure) {
                        _error(failure);
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Duplicate preset',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () async {
                      final name = await _nameDialog('Duplicate preset', '');
                      if (name == null) return;
                      try {
                        await _update(hotkeys.saveAs(name));
                      } catch (failure) {
                        _error(failure);
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Rename preset',
                    icon: const Icon(Icons.drive_file_rename_outline),
                    onPressed: hotkeys.activePreset == 'Default'
                        ? null
                        : () async {
                            final name = await _nameDialog(
                              'Rename preset',
                              hotkeys.activePreset,
                            );
                            if (name == null) return;
                            try {
                              await _update(
                                hotkeys.rename(hotkeys.activePreset, name),
                              );
                            } catch (failure) {
                              _error(failure);
                            }
                          },
                  ),
                  IconButton(
                    tooltip: 'Delete preset',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: hotkeys.activePreset == 'Default'
                        ? null
                        : () => _update(hotkeys.delete(hotkeys.activePreset)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search shortcuts or groups',
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            if (recording != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Focus(
                  focusNode: captureFocus,
                  onKeyEvent: _capture,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          warning ??
                              'Press a new combination for ${recording!.label}: ${pending?.display ?? 'Ctrl+…'}',
                        ),
                      ),
                      FilledButton(
                        onPressed: pending == null || warning != null
                            ? null
                            : () {
                                try {
                                  _update(
                                    hotkeys.withBinding(recording!, pending!),
                                  );
                                } catch (failure) {
                                  _error(failure);
                                }
                              },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            action.label,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          SettingsHelperText(action.group),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(hotkeys.bindings[action]!.display),
                              IconButton(
                                tooltip: 'Change ${action.label}',
                                icon: const Icon(Icons.keyboard_outlined),
                                onPressed: () {
                                  setState(() {
                                    recording = action;
                                    pending = null;
                                    warning = null;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => captureFocus.requestFocus(),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Reset ${action.label}',
                                icon: const Icon(Icons.restart_alt),
                                onPressed:
                                    hotkeys.bindings[action] ==
                                        HotkeyPreferences.defaults[action]
                                    ? null
                                    : () {
                                        try {
                                          _update(hotkeys.resetOne(action));
                                        } catch (failure) {
                                          _error(failure);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _update(hotkeys.resetAll()),
          child: const Text('Reset all'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
