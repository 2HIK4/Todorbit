import '../shared/scroll_edge_fade.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/color_picker_dialog.dart';
import '../shared/text_prompt_dialog.dart';

import '../../app/app_controller.dart';
import '../../domain/appearance.dart';
import '../workspace/windows_resource_dialog.dart';

class ThemeDialog extends ConsumerStatefulWidget {
  const ThemeDialog({super.key});

  @override
  ConsumerState<ThemeDialog> createState() => _ThemeDialogState();
}

class _ThemeDialogState extends ConsumerState<ThemeDialog> {
  bool dark = false;
  late ThemeCustomization draft;
  String? message;

  @override
  void initState() {
    super.initState();
    draft = ref.read(appControllerProvider).customization;
  }

  ThemePalette get palette => dark ? draft.dark : draft.light;
  ThemePalette get defaults => dark ? ThemePalette.dark : ThemePalette.light;

  void update(ThemePalette value) => setState(() {
    draft = dark ? draft.copyWith(dark: value) : draft.copyWith(light: value);
    message = null;
  });

  Future<void> editColor(String key) async {
    final chosen = await showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(
        title: _label(key),
        initialColor: palette[key],
        defaultColor: defaults[key],
      ),
    );
    if (chosen != null && mounted) update(palette.withColor(key, chosen));
  }

  Future<String?> askText(String title, {String initial = ''}) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(title: title, initial: initial),
    );
    return result?.trim();
  }

  Future<void> savePreset() async {
    final name = await askText('Save as preset');
    if (name == null || name.isEmpty) return;
    if (draft.presets.containsKey(name)) {
      setState(() => message = 'A preset with that name already exists.');
      return;
    }
    setState(
      () => draft = draft.copyWith(presets: {...draft.presets, name: palette}),
    );
  }

  Future<void> transfer(bool import) async {
    final path = await askText(
      import ? 'Import theme JSON path' : 'Export theme JSON path',
    );
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (import) {
        if (await file.length() > 65536) {
          throw const FormatException('Theme file is too large');
        }
        final value = ThemeCustomization.fromJson(
          jsonDecode(await file.readAsString()),
        );
        setState(() {
          draft = value;
          message = 'Theme imported. Save changes to apply it.';
        });
      } else {
        if (await file.exists()) {
          throw const FormatException('File already exists');
        }
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(draft.toJson()),
          flush: true,
        );
        setState(() => message = 'Theme exported.');
      }
    } catch (error) {
      setState(() => message = 'Theme file: $error');
    }
  }

  static String _label(String key) => key
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[0]}')
      .replaceFirstMapped(RegExp('^.'), (match) => match[0]!.toUpperCase());

  @override
  Widget build(BuildContext context) {
    final contrast = palette.contrast('primaryText', 'surface');
    return AlertDialog(
      title: const Text('Customize Theme'),
      content: SizedBox(
        width: 560,
        height: 560,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth <
                      360 * MediaQuery.textScalerOf(context).scale(1)
                  ? AnchoredSelectField<bool>(
                      initialValue: dark,
                      decoration: const InputDecoration(labelText: 'Palette'),
                      items: const [
                        DropdownMenuItem(
                          value: false,
                          child: Text('Light Mode'),
                        ),
                        DropdownMenuItem(value: true, child: Text('Dark Mode')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => dark = value);
                      },
                    )
                  : SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Light Mode')),
                        ButtonSegment(value: true, label: Text('Dark Mode')),
                      ],
                      selected: {dark},
                      onSelectionChanged: (value) =>
                          setState(() => dark = value.first),
                    ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FadingListView(
                padding: const EdgeInsets.only(top: 8, right: 8, bottom: 16),
                children: [
                  for (final key in ThemePalette.keys)
                    ListTile(
                      dense: true,
                      title: Text(_label(key)),
                      subtitle: Text(palette.toJson()[key]!),
                      trailing: CircleAvatar(
                        radius: 16,
                        backgroundColor: palette[key],
                      ),
                      onTap: () => editColor(key),
                    ),
                  const Divider(),
                  ListTile(
                    title: const Text('Preview task'),
                    subtitle: const Text(
                      'Your colors update here before saving.',
                    ),
                    tileColor: palette['surface'],
                    textColor: palette['primaryText'],
                    iconColor: palette['accent'],
                    leading: const Icon(Icons.check_circle_outline),
                  ),
                  if (contrast < 4.5)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Contrast warning: primary text on surface is ${contrast.toStringAsFixed(1)}:1; aim for at least 4.5:1.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => update(
                          dark ? ThemePalette.dusk : ThemePalette.ocean,
                        ),
                        child: Text(dark ? 'Try Dusk' : 'Try Ocean'),
                      ),
                      TextButton(
                        onPressed: () => update(defaults),
                        child: const Text('Reset this mode'),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => draft = const ThemeCustomization()),
                        child: const Text('Reset all themes'),
                      ),
                      TextButton(
                        onPressed: savePreset,
                        child: const Text('Save as preset'),
                      ),
                    ],
                  ),
                  for (final entry in draft.presets.entries)
                    ListTile(
                      title: Text(entry.key),
                      onTap: () => update(entry.value),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'delete') {
                            setState(() {
                              final next = {...draft.presets}
                                ..remove(entry.key);
                              draft = draft.copyWith(presets: next);
                            });
                          } else if (action == 'rename' ||
                              action == 'duplicate') {
                            final name = await askText(
                              action == 'rename'
                                  ? 'Rename preset'
                                  : 'Duplicate preset',
                              initial: action == 'rename'
                                  ? entry.key
                                  : '${entry.key} copy',
                            );
                            if (name == null ||
                                name.isEmpty ||
                                draft.presets.containsKey(name)) {
                              return;
                            }
                            setState(() {
                              final next = {...draft.presets};
                              if (action == 'rename') next.remove(entry.key);
                              next[name] = entry.value;
                              draft = draft.copyWith(presets: next);
                            });
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'duplicate',
                            child: Text('Duplicate'),
                          ),
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => transfer(true),
                        child: const Text('Import JSON'),
                      ),
                      TextButton(
                        onPressed: () => transfer(false),
                        child: const Text('Export JSON'),
                      ),
                    ],
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(message!),
                    ),
                  if (draft.author != null)
                    ListTile(
                      dense: true,
                      title: Text('Theme by ${draft.author}'),
                      trailing: draft.authorProfile == null
                          ? null
                          : const Icon(Icons.open_in_new),
                      onTap: draft.authorProfile == null
                          ? null
                          : () async {
                              try {
                                await const WindowsResourceDialog().open(
                                  draft.authorProfile.toString(),
                                );
                              } catch (error) {
                                setState(
                                  () => message =
                                      'Could not open profile: $error',
                                );
                              }
                            },
                    ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Compact task and control spacing'),
                    value: draft.compact,
                    onChanged: (value) =>
                        setState(() => draft = draft.copyWith(compact: value)),
                  ),
                  ListTile(
                    title: Text(
                      'Text scale · ${(draft.textScale * 100).round()}%',
                    ),
                    subtitle: Slider(
                      value: draft.textScale,
                      min: 0.85,
                      max: 1.5,
                      divisions: 13,
                      onChanged: (value) => setState(
                        () => draft = draft.copyWith(textScale: value),
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text('Sidebar width · ${draft.sidebarWidth}px'),
                    subtitle: Slider(
                      value: draft.sidebarWidth.toDouble(),
                      min: 190,
                      max: 330,
                      divisions: 14,
                      onChanged: (value) => setState(
                        () =>
                            draft = draft.copyWith(sidebarWidth: value.round()),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: AnchoredSelectField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Opening screen',
                      ),
                      key: ValueKey(draft.openingScreen),
                      initialValue: draft.openingScreen,
                      items: const [
                        DropdownMenuItem(value: 'today', child: Text('Today')),
                        DropdownMenuItem(value: 'inbox', child: Text('Inbox')),
                        DropdownMenuItem(
                          value: 'calendar',
                          child: Text('Calendar'),
                        ),
                        DropdownMenuItem(
                          value: 'habits',
                          child: Text('Habits'),
                        ),
                        DropdownMenuItem(value: 'goals', child: Text('Goals')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(
                            () => draft = draft.copyWith(openingScreen: value),
                          );
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: AnchoredSelectField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Default calendar view',
                      ),
                      key: ValueKey(draft.calendarDefaultView),
                      initialValue: draft.calendarDefaultView,
                      items: const [
                        DropdownMenuItem(value: 'day', child: Text('Day')),
                        DropdownMenuItem(value: 'week', child: Text('Week')),
                        DropdownMenuItem(value: 'month', child: Text('Month')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(
                            () => draft = draft.copyWith(
                              calendarDefaultView: value,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Reduce motion'),
                    subtitle: const Text('Use fewer interface animations'),
                    value: draft.reducedMotion,
                    onChanged: (value) => setState(
                      () => draft = draft.copyWith(reducedMotion: value),
                    ),
                  ),
                  const ListTile(
                    title: Text('Widget appearance'),
                    subtitle: Text(
                      'Configure each widget’s surfaces, opacity and borders in Settings > Widget.',
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref.read(appControllerProvider).saveCustomization(draft);
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              setState(() => message = 'Could not save theme: $error');
            }
          },
          child: const Text('Save changes'),
        ),
      ],
    );
  }
}
