import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import 'settings_transfer.dart';
import 'windows_settings_file_dialog.dart';
import '../../platform/android/android_platform.dart';

class SettingsTransferDialog extends ConsumerStatefulWidget {
  const SettingsTransferDialog({
    super.key,
    this.chooseImport,
    this.chooseExport,
    this.initialTransfer,
    this.uploadSettings,
    this.cloudProgress,
  });

  final Future<File?> Function()? chooseImport;
  final Future<File?> Function()? chooseExport;
  final SettingsTransfer? initialTransfer;
  final Future<void> Function(String encoded)? uploadSettings;
  final ValueListenable<({String stage, double? fraction})>? cloudProgress;

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

  @override
  void initState() {
    super.initState();
    imported = widget.initialTransfer;
    if (imported != null) selected = imported!.categories.keys.toSet();
  }

  Future<void> _upload() async {
    setState(() => busy = true);
    try {
      await widget.uploadSettings!(
        SettingsTransfer.fromController(ref.read(appControllerProvider))
            .encode(selected),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => message = '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _preview(SettingsCategory category, AppController current) {
    final value = imported?.categories[category];
    if (value == null) return '';
    return switch (category) {
      SettingsCategory.widgets =>
        'Widget appearance, navigation order, layout and custom presets',
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
      if (Platform.isAndroid && widget.chooseExport == null) {
        final temporary = await Directory.systemTemp.createTemp(
          'todorbit-settings-',
        );
        try {
          final file = File('${temporary.path}/settings.json');
          await SettingsTransfer.fromController(ref.read(appControllerProvider))
              .exportTo(file, selected);
          final exported = await AndroidPlatform.exportDocument(
            file,
            name: 'Todorbit-settings.json',
            mime: 'application/json',
          );
          if (mounted && exported) {
            setState(() => message = 'Settings exported.');
          }
        } finally {
          await temporary.delete(recursive: true);
        }
        return;
      }
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
      title: Text(
        widget.initialTransfer != null
            ? 'Restore cloud settings'
            : widget.uploadSettings != null
            ? 'Back up settings to Google Drive'
            : 'Share settings',
      ),
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
                if (busy && widget.cloudProgress != null)
                  ValueListenableBuilder(
                    valueListenable: widget.cloudProgress!,
                    builder: (context, value, _) => Column(
                      children: [
                        Text(value.stage),
                        LinearProgressIndicator(value: value.fraction),
                        if (value.fraction != null)
                          Text('${(value.fraction! * 100).round()}%'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.initialTransfer == null && widget.uploadSettings == null)
          TextButton(
            onPressed: busy ? null : _import,
            child: const Text('Import JSON'),
          ),
        if (widget.initialTransfer == null && widget.uploadSettings == null)
          TextButton(
            onPressed: busy || selected.isEmpty ? null : _export,
            child: const Text('Export JSON'),
          ),
        if (imported != null)
          FilledButton(
            onPressed: busy || selected.isEmpty ? null : _apply,
            child: const Text('Apply selected'),
          ),
        if (widget.uploadSettings != null)
          FilledButton(
            onPressed: busy || selected.isEmpty ? null : _upload,
            child: const Text('Back up selected settings'),
          ),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
