import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import 'settings_transfer.dart';
import 'windows_settings_file_dialog.dart';

class SettingsTransferDialog extends ConsumerStatefulWidget {
  const SettingsTransferDialog({
    super.key,
    this.chooseImport,
    this.chooseExport,
  });

  final Future<File?> Function()? chooseImport;
  final Future<File?> Function()? chooseExport;

  @override
  ConsumerState<SettingsTransferDialog> createState() =>
      _SettingsTransferDialogState();
}

class _SettingsTransferDialogState
    extends ConsumerState<SettingsTransferDialog> {
  SettingsTransfer? imported;
  Set<SettingsCategory> selected = SettingsCategory.values.toSet();
  String? message;
  bool busy = false;
  bool mergeHotkeys = false;

  String _preview(SettingsCategory category, AppController current) {
    final value = imported?.categories[category];
    if (value == null) return '';
    return switch (category) {
      SettingsCategory.appearance =>
        'Theme mode: ${value['mode'] ?? 'keep current'}; light and dark colors plus theme presets',
      SettingsCategory.hotkeys => () {
        final raw = value['presets'] as Map<String, dynamic>;
        final names = (raw['presets'] as Map).keys.whereType<String>().toList();
        final conflicts = names
            .where(current.hotkeys.presets.containsKey)
            .length;
        return '${names.length} custom presets; $conflicts name conflicts with current presets; active: ${raw['active']}';
      }(),
      SettingsCategory.calendar =>
        'Content: ${value['content']}; first weekday: ${value['firstWeekday']}; last view: ${value['lastMode'] ?? 'keep current'}',
      SettingsCategory.navigation =>
        'Sidebar order: ${(value['sidebarOrder'] as List).join(', ')}',
      SettingsCategory.taskDisplay =>
        'New task day: ${value['newTaskPlannedDay']}; completed visible: ${value['keepCompletedVisible']}; spelling: ${value['spellCheckEnabled']}; checklist text: ${value['compositionTextDisplay']}',
    };
  }

  Future<void> _import() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final file =
          await (widget.chooseImport ??
              const WindowsSettingsFileDialog().chooseImport)();
      if (file == null) return;
      final transfer = await SettingsTransfer.read(file);
      if (mounted) {
        setState(() {
          imported = transfer;
          selected = transfer.categories.keys.toSet();
          message = 'Review the categories below before applying them.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = 'Could not import settings: $error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _export() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final file =
          await (widget.chooseExport ??
              const WindowsSettingsFileDialog().chooseExport)();
      if (file == null) return;
      await SettingsTransfer.fromController(ref.read(appControllerProvider))
          .exportTo(file, selected);
      if (mounted) {
        setState(() => message = 'Settings exported to ${file.path}');
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = 'Could not export settings: $error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _apply() async {
    final transfer = imported;
    if (transfer == null || selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply selected settings?'),
        content: Text(
          'These categories will update your personalization: ${selected.map((item) => item.label).join(', ')}. ${mergeHotkeys ? 'Hotkey presets will merge; matching names receive a number. ' : ''}Other selected categories replace their current values. Tasks and events are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply settings'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await transfer.applyTo(
        ref.read(appControllerProvider),
        selected,
        mergeHotkeys: mergeHotkeys,
      );
      if (mounted) {
        setState(() {
          imported = null;
          message = 'Selected settings applied.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => message = 'Could not apply all settings: $error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appControllerProvider);
    final available =
        imported?.categories.keys.toSet() ?? SettingsCategory.values.toSet();
    return AlertDialog(
      title: const Text('Share settings'),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      buttonPadding: const EdgeInsets.symmetric(horizontal: 8),
      content: SizedBox(
        width: 540,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export a portable JSON file with your selected personalization. It does not contain database records, PINs, or local file paths.',
                ),
                const SizedBox(height: 12),
                for (final category in available)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(category.label),
                    subtitle: imported == null
                        ? null
                        : Text(_preview(category, current)),
                    value: selected.contains(category),
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              selected.add(category);
                            } else {
                              selected.remove(category);
                            }
                          }),
                  ),
                if (imported != null)
                  const Text(
                    'Imported file validated. Select the categories to replace, then apply.',
                  ),
                if (imported != null &&
                    selected.contains(SettingsCategory.hotkeys))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Merge hotkey presets'),
                    subtitle: const Text(
                      'Keep current presets and add imported copies. Matching names receive a number.',
                    ),
                    value: mergeHotkeys,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => mergeHotkeys = value),
                  ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(message!),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : _import,
          child: const Text('Import JSON'),
        ),
        TextButton(
          onPressed: busy || selected.isEmpty ? null : _export,
          child: const Text('Export JSON'),
        ),
        if (imported != null)
          FilledButton(
            onPressed: busy || selected.isEmpty ? null : _apply,
            child: const Text('Apply selected'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
