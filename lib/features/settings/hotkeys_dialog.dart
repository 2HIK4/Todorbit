import '../shared/scroll_edge_fade.dart';
import '../shared/app_motion.dart';
import '../shared/app_spacing.dart';

import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/hotkeys.dart';
import '../shared/settings_section.dart';
import '../shared/text_prompt_dialog.dart';

/// Complete Hotkeys editor shared by the embedded Settings > Hotkeys pane
/// (`embedded: true`) and the standalone [HotkeysDialog] (`embedded: false`).
class HotkeysEditorView extends ConsumerStatefulWidget {
  const HotkeysEditorView({super.key, this.embedded = true});

  final bool embedded;

  @override
  ConsumerState<HotkeysEditorView> createState() => _HotkeysEditorViewState();
}

class _HotkeysEditorViewState extends ConsumerState<HotkeysEditorView> {
  final captureFocus = FocusNode();
  final Map<HotkeyAction, FocusNode> _rowFocusNodes = {};
  HotkeyAction? _lastTrigger;
  String query = '';
  HotkeyAction? recording;
  HotkeyBinding? pending;
  String? warning;
  HotkeyPreferences? _seenHotkeys;

  FocusNode _rowFocus(HotkeyAction action) =>
      _rowFocusNodes.putIfAbsent(action, () => FocusNode());

  @override
  void dispose() {
    captureFocus.dispose();
    for (final node in _rowFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _cancelRecording() {
    final target = recording ?? _lastTrigger;
    setState(() {
      recording = null;
      pending = null;
      warning = null;
    });
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rowFocus(target).requestFocus();
      });
    }
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
      animationStyle: AppMotion.style(context),
      builder: (_) => TextPromptDialog(
        title: title,
        initial: initial,
        label: 'Preset name',
        maxLength: 40,
        submitLabel: 'Save',
      ),
    );
  }

  static bool _isModifierOnlyKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight;

  KeyEventResult _capture(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelRecording();
      return KeyEventResult.handled;
    }
    if (_isModifierOnlyKey(event.logicalKey)) {
      return KeyEventResult.handled;
    }
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

  Widget _presetControls(HotkeyPreferences hotkeys) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 4,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: constraints.maxWidth < 540
              ? constraints.maxWidth
              : constraints.maxWidth - (widget.embedded ? 332 : 216),
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
            final name = await _nameDialog('Save shortcut preset', '');
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
            final name = await _nameDialog(
              'Duplicate preset',
              '${hotkeys.activePreset} copy',
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
                    await _update(hotkeys.rename(hotkeys.activePreset, name));
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
        if (widget.embedded)
          TextButton(
            onPressed: () => _update(hotkeys.resetAll()),
            child: const Text('Reset all'),
          ),
      ],
    ),
  );

  Widget _captureBanner(HotkeyPreferences hotkeys) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Focus(
        focusNode: captureFocus,
        onKeyEvent: _capture,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: warning != null ? scheme.error : scheme.primary,
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                warning ??
                    'Press a new combination for ${recording!.label}: ${pending?.display ?? 'Ctrl+…'}',
                style: warning != null ? TextStyle(color: scheme.error) : null,
              ),
              TextButton(
                onPressed: _cancelRecording,
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: pending == null || warning != null
                    ? null
                    : () {
                        try {
                          _update(hotkeys.withBinding(recording!, pending!));
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
    );
  }

  List<Widget> _shortcutItems(
    BuildContext context,
    HotkeyPreferences hotkeys,
    List<HotkeyAction> actions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      if (actions.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: SettingsHelperText('No shortcuts match your search.'),
        ),
      for (final action in actions)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SettingsHelperText(action.group),
                ],
              );
              final controls = Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      hotkeys.bindings[action]!.display,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  IconButton(
                    focusNode: _rowFocus(action),
                    tooltip: 'Change ${action.label}',
                    icon: const Icon(Icons.keyboard_outlined),
                    onPressed: () {
                      setState(() {
                        _lastTrigger = action;
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
              );
              if (constraints.maxWidth < 460) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [titleBlock, const SizedBox(height: 4), controls],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 8),
                  controls,
                ],
              );
            },
          ),
        ),
      const Divider(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendar shortcuts',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const SettingsHelperText(
              'Active while viewing the Calendar:\n'
              '• Ctrl+1: Day view\n'
              '• Ctrl+2: Week view\n'
              '• Ctrl+3: Month view\n'
              '• T: Jump to today (when not typing)\n'
              '• Ctrl+Z: Undo reschedule or resize\n'
              '• Escape: Cancel active drag or resize\n'
              '• Ctrl+Scroll: Zoom in/out anchored at cursor',
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final hotkeys = controller.hotkeys;
    if (_seenHotkeys != null && _seenHotkeys != hotkeys && recording != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && recording != null) {
          setState(() {
            recording = null;
            pending = null;
            warning = null;
          });
        }
      });
    }
    _seenHotkeys = hotkeys;
    final actions = HotkeyAction.values
        .where(
          (action) => '${action.group} ${action.label}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    final items = _shortcutItems(context, hotkeys, actions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.embedded ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (widget.embedded) ...[
          const SettingsHelperText(
            'Search shortcuts, customize bindings, resolve conflicts, and manage presets.',
          ),
          const SizedBox(height: 12),
        ],
        _presetControls(hotkeys),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search shortcuts or groups',
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        if (recording != null) _captureBanner(hotkeys),
        const SizedBox(height: 8),
        if (widget.embedded)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items,
          )
        else
          Expanded(child: FadingListView(children: items)),
      ],
    );
  }
}

class HotkeysDialog extends ConsumerWidget {
  const HotkeysDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    return AlertDialog(
      title: const Text('Hotkeys'),
      content: const SizedBox(
        width: 600,
        height: 560,
        child: HotkeysEditorView(embedded: false),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            try {
              await controller.setHotkeys(controller.hotkeys.resetAll());
            } catch (failure) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$failure')));
              }
            }
          },
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
