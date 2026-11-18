import '../shared/app_motion.dart';
import '../shared/text_prompt_dialog.dart';
import '../../domain/task_resources.dart';
import '../../domain/models.dart';
import '../../data/app_database.dart';
import '../../data/life_repository.dart';
import '../../data/shared_inbox_store.dart';
import '../../domain/shared_inbox_entry.dart';
import '../../platform/android/android_platform.dart';
import '../shared_inbox/shared_inbox_picker_dialog.dart';
import 'windows_resource_dialog.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class UnifiedResourcesSection extends StatefulWidget {
  const UnifiedResourcesSection.draft({
    super.key,
    required List<DraftTaskResource> resources,
    required ValueChanged<List<DraftTaskResource>> onChanged,
    this.subtasks = const [],
    this.resourceSubtaskMap = const {},
    this.onResourceSubtasksChanged,
    this.onAddSubtask,
    this.sharedInboxStore,
  }) : taskId = null,
       repository = null,
       draftResources = resources,
       onDraftChanged = onChanged,
       isDraft = true;

  const UnifiedResourcesSection.persisted({
    super.key,
    required this.taskId,
    required this.repository,
    this.subtasks = const [],
    this.onAddSubtask,
    this.sharedInboxStore,
  }) : draftResources = null,
       onDraftChanged = null,
       resourceSubtaskMap = null,
       onResourceSubtasksChanged = null,
       isDraft = false;

  final bool isDraft;
  final String? taskId;
  final LifeRepository? repository;
  final List<DraftTaskResource>? draftResources;
  final ValueChanged<List<DraftTaskResource>>? onDraftChanged;
  final List<LifeTask> subtasks;
  final Map<String, List<String>>? resourceSubtaskMap;
  final ValueChanged<Map<String, List<String>>>? onResourceSubtasksChanged;
  final Future<LifeTask?> Function(String title)? onAddSubtask;
  final SharedInboxStore? sharedInboxStore;

  @override
  State<UnifiedResourcesSection> createState() =>
      _UnifiedResourcesSectionState();
}

class _UnifiedResourcesSectionState extends State<UnifiedResourcesSection> {
  static const _dropChannel = MethodChannel('life_manager/file_drop');
  static final _dropTargets = <_UnifiedResourcesSectionState>[];
  final _dropArea = GlobalKey();
  final _dialog = const WindowsResourceDialog();

  bool dropAvailable = false;
  bool dropHover = false;
  bool picking = false;
  bool busy = false;
  String? error;

  List<TaskResource>? persistedResources;
  final availability = <String, bool>{};
  Map<String, List<String>> persistedSubtaskMap = {};

  @override
  void initState() {
    super.initState();
    if (!widget.isDraft) {
      _reloadPersisted();
    }
    if (Platform.isWindows) {
      _dropTargets.add(this);
      _dropChannel.setMethodCallHandler((call) async {
        if (_dropTargets.isNotEmpty) {
          await _dropTargets.last._handleDropEvent(call);
        }
      });
      _dropChannel
          .invokeMethod<bool>('available')
          .then((available) {
            if (mounted) setState(() => dropAvailable = available == true);
          })
          .catchError((Object _) {});
    }
  }

  @override
  void didUpdateWidget(covariant UnifiedResourcesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isDraft && oldWidget.taskId != widget.taskId) {
      _reloadPersisted();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      _dropTargets.remove(this);
      if (_dropTargets.isEmpty) _dropChannel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  bool _insideDropArea(dynamic arguments) {
    if (arguments is! Map) return false;
    final x = arguments['x'];
    final y = arguments['y'];
    final render = _dropArea.currentContext?.findRenderObject();
    if (x is! num || y is! num || render is! RenderBox) return false;
    final local = render.globalToLocal(Offset(x.toDouble(), y.toDouble()));
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx < render.size.width &&
        local.dy < render.size.height;
  }

  Future<void> _handleDropEvent(MethodCall call) async {
    if (!mounted) return;
    if (call.method == 'leave') {
      if (dropHover) setState(() => dropHover = false);
      return;
    }
    final inside = _insideDropArea(call.arguments);
    if (call.method == 'hover') {
      if (inside != dropHover) setState(() => dropHover = inside);
      return;
    }
    if (dropHover) setState(() => dropHover = false);
    if (!const {'drop', 'urlDrop'}.contains(call.method) || !inside || busy) {
      return;
    }
    final arguments = call.arguments;
    final raw = arguments is Map
        ? arguments[call.method == 'urlDrop' ? 'urls' : 'files']
        : null;
    if (raw is! List) return;
    final paths = raw.whereType<String>().toList();
    if (paths.isEmpty) return;
    if (call.method == 'urlDrop') {
      await _addDroppedUrls(paths);
    } else {
      await _acceptDrop(paths);
    }
  }

  Future<void> _addDroppedUrls(List<String> urls) => _run(() async {
    final normalized = urls.map(normalizeResourceUrl).toSet();
    if (widget.isDraft) {
      widget.onDraftChanged?.call([
        ...?widget.draftResources,
        for (final url in normalized)
          DraftTaskResource(TaskResourceKind.url, url, url),
      ]);
    } else {
      for (final url in normalized) {
        await widget.repository!.addExternalResource(
          widget.taskId!,
          TaskResourceKind.url,
          url,
        );
      }
    }
  });

  Future<void> _acceptDrop(List<String> paths) async {
    // Check for InternetShortcut files (.url) or regular files
    final validFiles = <String>[];
    final extractedUrls = <String>[];

    for (final rawPath in paths) {
      final ext = path.extension(rawPath).toLowerCase();
      if (ext == '.url') {
        try {
          final content = await File(rawPath).readAsString();
          final match = RegExp(
            r'URL=(.+)',
            caseSensitive: false,
          ).firstMatch(content);
          if (match != null && match.group(1) != null) {
            extractedUrls.add(match.group(1)!.trim());
            continue;
          }
        } catch (_) {}
      }
      validFiles.add(rawPath);
    }

    await _addDroppedUrls(extractedUrls);

    if (validFiles.isEmpty) return;

    final unique = <String, String>{};
    for (final entered in validFiles) {
      final absolute = path.normalize(path.absolute(entered));
      unique[absolute.toLowerCase()] = absolute;
    }

    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (context) => AlertDialog(
        title: Text(
          'Add ${unique.length} file${unique.length == 1 ? '' : 's'}?',
        ),
        content: const Text(
          'Attach stores portable copies in the task database. '
          'Link keeps files at their original location on this computer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'link'),
            child: const Text('Link originals'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'attach'),
            child: const Text('Attach copies'),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    if (widget.isDraft) {
      final current = List.of(widget.draftResources ?? <DraftTaskResource>[]);
      for (final filePath in unique.values) {
        final isDir = FileSystemEntity.isDirectorySync(filePath);
        final kind = isDir
            ? TaskResourceKind.externalFolder
            : choice == 'link'
            ? TaskResourceKind.externalFile
            : TaskResourceKind.managed;
        current.add(DraftTaskResource(kind, filePath, path.basename(filePath)));
      }
      widget.onDraftChanged?.call(current);
    } else {
      await _run(() async {
        for (final filePath in unique.values) {
          final isDir = FileSystemEntity.isDirectorySync(filePath);
          if (choice == 'link' || isDir) {
            await widget.repository!.addExternalResource(
              widget.taskId!,
              isDir
                  ? TaskResourceKind.externalFolder
                  : TaskResourceKind.externalFile,
              filePath,
            );
          } else {
            await widget.repository!.attachManagedFile(
              widget.taskId!,
              File(filePath),
            );
          }
        }
      });
    }
  }

  Future<void> _reloadPersisted() async {
    if (widget.taskId == null || widget.repository == null) return;
    try {
      final loaded = await widget.repository!.taskResources(widget.taskId!);
      final subMap = await widget.repository!.taskResourceSubtaskMap(
        widget.taskId!,
      );
      final states = <String, bool>{};
      for (final resource in loaded) {
        if (resource.kind == TaskResourceKind.externalFile ||
            resource.kind == TaskResourceKind.externalFolder) {
          try {
            states[resource.id] =
                await FileSystemEntity.type(
                  resource.target!,
                  followLinks: false,
                ) ==
                (resource.kind == TaskResourceKind.externalFile
                    ? FileSystemEntityType.file
                    : FileSystemEntityType.directory);
          } on FileSystemException {
            states[resource.id] = false;
          }
        }
      }
      if (mounted) {
        setState(() {
          persistedResources = loaded;
          persistedSubtaskMap = subMap;
          availability
            ..clear()
            ..addAll(states);
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (!widget.isDraft) await _reloadPersisted();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pickFileOrFolder(TaskResourceKind kind) async {
    if (picking || busy) return;
    setState(() => picking = true);
    try {
      final target = kind == TaskResourceKind.externalFolder
          ? (await _dialog.chooseFolder())?.path
          : (await _dialog.chooseFile())?.path;

      if (target != null && !context.mounted && Platform.isAndroid) {
        await AndroidPlatform.releaseImportedDocument(File(target));
        return;
      }

      if (target != null && mounted) {
        if (widget.isDraft) {
          final next = List.of(widget.draftResources ?? <DraftTaskResource>[]);
          next.add(DraftTaskResource(kind, target, path.basename(target)));
          widget.onDraftChanged?.call(next);
        } else if (widget.taskId != null && widget.repository != null) {
          await _run(() async {
            if (kind == TaskResourceKind.managed) {
              await widget.repository!.attachManagedFile(
                widget.taskId!,
                File(target),
              );
            } else {
              await widget.repository!.addExternalResource(
                widget.taskId!,
                kind,
                target,
              );
            }
          });
        }
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select resource: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> _attachFromSharedInbox() async {
    if (busy || picking) return;
    final inboxStore = widget.sharedInboxStore ?? SharedInboxStore();

    final existingShas = <String>{};
    if (!widget.isDraft && persistedResources != null) {
      for (final r in persistedResources!) {
        if (r.sha256 != null) {
          existingShas.add(r.sha256!);
        }
      }
    }

    final selected = await showDialog<List<SharedInboxEntry>>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (_) => SharedInboxPickerDialog(
        store: inboxStore,
        alreadyAttachedShas: existingShas,
      ),
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    if (widget.isDraft) {
      final next = List.of(widget.draftResources ?? <DraftTaskResource>[]);
      for (final entry in selected) {
        final file = entry.fileIn(inboxStore.directory);
        next.add(
          DraftTaskResource(
            TaskResourceKind.managed,
            file.path,
            entry.displayName,
          ),
        );
      }
      widget.onDraftChanged?.call(next);
    } else if (widget.taskId != null && widget.repository != null) {
      await _run(() async {
        for (final entry in selected) {
          final file = entry.fileIn(inboxStore.directory);
          if (file.existsSync()) {
            final resource = await widget.repository!.attachManagedFile(
              widget.taskId!,
              file,
            );
            if (resource.label != entry.displayName) {
              await widget.repository!.renameTaskResource(
                resource,
                entry.displayName,
              );
            }
          }
        }
      });
    }
  }

  Future<void> _addUrl() async {
    final target = await showDialog<String>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (_) => TextPromptDialog(
        title: 'Add URL',
        label: 'Website or application link (e.g. https://... or domain.com)',
        maxLength: null,
        save: (value) async {
          normalizeResourceUrl(value);
        },
      ),
    );

    if (target != null && mounted) {
      final normalized = normalizeResourceUrl(target);
      if (widget.isDraft) {
        final next = List.of(widget.draftResources ?? <DraftTaskResource>[]);
        next.add(
          DraftTaskResource(TaskResourceKind.url, normalized, normalized),
        );
        widget.onDraftChanged?.call(next);
      } else if (widget.taskId != null && widget.repository != null) {
        await _run(() async {
          await widget.repository!.addExternalResource(
            widget.taskId!,
            TaskResourceKind.url,
            normalized,
          );
        });
      }
    }
  }

  Future<void> _openResource(TaskResource resource) async {
    await _run(() async {
      if (resource.kind == TaskResourceKind.managed) {
        final extension = path
            .extension(resource.originalName ?? '')
            .toLowerCase();
        if (_unsafeExtension(extension)) {
          throw StateError(
            'Executable or shortcut attachments cannot be opened here',
          );
        }
        final bytes = await widget.repository!.managedAttachmentBytes(resource);
        final cache = Directory(
          path.join(
            (await AppDatabase.defaultFile()).parent.path,
            'attachment-cache',
          ),
        );
        await cache.create(recursive: true);
        final target = File(path.join(cache.path, '${resource.id}$extension'));
        final temporary = File('${target.path}.tmp');
        try {
          await temporary.writeAsBytes(bytes, flush: true);
          if (await target.exists()) await target.delete();
          await temporary.rename(target.path);
        } catch (_) {
          if (await temporary.exists()) await temporary.delete();
          rethrow;
        }
        await _dialog.open(target.path);
        return;
      }
      final target = resource.target!;
      if (resource.kind == TaskResourceKind.url) {
        final scheme = Uri.parse(target).scheme.toLowerCase();
        if (scheme != 'http' && scheme != 'https') {
          final approved = await showDialog<bool>(
            context: context,
            animationStyle: AppMotion.style(context),
            builder: (context) => AlertDialog(
              title: const Text('Open application link?'),
              scrollable: true,
              content: Text(target),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open link'),
                ),
              ],
            ),
          );
          if (approved != true) return;
        }
      } else {
        final kind = await FileSystemEntity.type(target, followLinks: false);
        final expected = resource.kind == TaskResourceKind.externalFile
            ? FileSystemEntityType.file
            : FileSystemEntityType.directory;
        if (kind != expected) {
          throw StateError('External resource is unavailable');
        }
        if (resource.kind == TaskResourceKind.externalFile &&
            _unsafeExtension(path.extension(target).toLowerCase())) {
          throw StateError(
            'Executable or shortcut files cannot be opened here',
          );
        }
      }
      await _dialog.open(target);
    });
  }

  Future<void> _renameResource(String id, String currentLabel) async {
    final newLabel = await showDialog<String>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (_) => TextPromptDialog(
        title: 'Rename resource',
        initial: currentLabel,
        label: 'Resource name',
        save: (value) async {
          if (value.trim().isEmpty) throw ArgumentError('Enter a name');
        },
      ),
    );

    if (newLabel != null && newLabel.trim().isNotEmpty && mounted) {
      if (widget.isDraft) {
        final index = int.tryParse(id);
        if (index != null &&
            index >= 0 &&
            index < (widget.draftResources?.length ?? 0)) {
          final next = List.of(widget.draftResources!);
          final item = next[index];
          next[index] = DraftTaskResource(
            item.kind,
            item.target,
            newLabel.trim(),
          );
          widget.onDraftChanged?.call(next);
        }
      } else if (widget.repository != null && persistedResources != null) {
        final resource = persistedResources!
            .where((r) => r.id == id)
            .firstOrNull;
        if (resource != null) {
          await _run(
            () => widget.repository!.renameTaskResource(
              resource,
              newLabel.trim(),
            ),
          );
        }
      }
    }
  }

  Future<void> _editUrl(String id, String currentUrl) async {
    final newUrl = await showDialog<String>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (_) => TextPromptDialog(
        title: 'Edit URL',
        initial: currentUrl,
        label: 'Website or application link',
        save: (value) async {
          normalizeResourceUrl(value);
        },
      ),
    );

    if (newUrl != null && mounted) {
      final normalized = normalizeResourceUrl(newUrl);
      if (widget.isDraft) {
        final index = int.tryParse(id);
        if (index != null &&
            index >= 0 &&
            index < (widget.draftResources?.length ?? 0)) {
          final next = List.of(widget.draftResources!);
          final item = next[index];
          next[index] = DraftTaskResource(item.kind, normalized, item.label);
          widget.onDraftChanged?.call(next);
        }
      } else if (widget.repository != null && persistedResources != null) {
        final resource = persistedResources!
            .where((r) => r.id == id)
            .firstOrNull;
        if (resource != null) {
          await _run(
            () => widget.repository!.updateTaskUrl(resource, normalized),
          );
        }
      }
    }
  }

  Future<void> _removeResource(
    String id,
    String label,
    TaskResourceKind kind,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (context) => AlertDialog(
        title: const Text('Remove resource?'),
        content: Text(
          kind == TaskResourceKind.managed
              ? 'The stored copy of "$label" will be removed.'
              : kind == TaskResourceKind.url
              ? 'The link "$label" will be removed.'
              : 'The link to "$label" will be removed. The file on disk will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (approved == true && mounted) {
      if (widget.isDraft) {
        final index = int.tryParse(id);
        if (index != null &&
            index >= 0 &&
            index < (widget.draftResources?.length ?? 0)) {
          final next = List.of(widget.draftResources!)..removeAt(index);
          widget.onDraftChanged?.call(next);
        }
      } else if (widget.repository != null && persistedResources != null) {
        final resource = persistedResources!
            .where((r) => r.id == id)
            .firstOrNull;
        if (resource != null) {
          await _run(() => widget.repository!.removeTaskResource(resource));
        }
      }
    }
  }

  Future<void> _assignSubtasks(String resourceId, String resourceLabel) async {
    final availableSubtasks = List.of(widget.subtasks);
    final currentAssigned = widget.isDraft
        ? (widget.resourceSubtaskMap?[resourceId] ?? <String>[])
        : (persistedSubtaskMap[resourceId] ?? <String>[]);
    final selectedIds = Set<String>.from(currentAssigned);

    final result = await showDialog<Set<String>>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign "$resourceLabel" to Subtasks'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (availableSubtasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      widget.onAddSubtask == null
                          ? 'No subtasks available. Subtasks support one level only.'
                          : 'No subtasks yet. Add one below to associate.',
                    ),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final subtask in availableSubtasks)
                            CheckboxListTile(
                              title: Text(subtask.title),
                              value: selectedIds.contains(subtask.id),
                              onChanged: (checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    selectedIds.add(subtask.id);
                                  } else {
                                    selectedIds.remove(subtask.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (widget.onAddSubtask != null)
                  TextButton.icon(
                    onPressed: () async {
                      final name = await showDialog<String>(
                        context: context,
                        animationStyle: AppMotion.style(context),
                        builder: (_) => const TextPromptDialog(
                          title: 'New Subtask',
                          label: 'Subtask title',
                        ),
                      );
                      if (name != null && name.trim().isNotEmpty) {
                        final created = await widget.onAddSubtask!(name.trim());
                        if (created != null && mounted) {
                          setDialogState(() {
                            availableSubtasks.add(created);
                            selectedIds.add(created.id);
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add subtask'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, selectedIds),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      if (widget.isDraft) {
        final currentMap = Map<String, List<String>>.from(
          widget.resourceSubtaskMap ?? {},
        );
        currentMap[resourceId] = result.toList();
        widget.onResourceSubtasksChanged?.call(currentMap);
      } else if (widget.repository != null) {
        await _run(() async {
          await widget.repository!.assignResourceToSubtasks(
            resourceId,
            result.toList(),
          );
        });
      }
    }
  }

  IconData _iconForKind(TaskResourceKind kind, String? target, String? label) {
    if (kind == TaskResourceKind.url) return Icons.language_outlined;
    if (kind == TaskResourceKind.externalFolder) return Icons.folder_outlined;
    final ext = path.extension(target ?? label ?? '').toLowerCase();
    if (const {
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.bmp',
      '.svg',
    }.contains(ext)) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final draftItems = widget.draftResources ?? <DraftTaskResource>[];
    final hasItems = widget.isDraft
        ? draftItems.isNotEmpty
        : (persistedResources?.isNotEmpty ?? false);

    return Container(
      key: _dropArea,
      decoration: BoxDecoration(
        color: dropHover
            ? scheme.primaryContainer.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border.all(
          color: dropHover
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: dropHover ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_shared_outlined,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Resources',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (dropAvailable && dropHover)
                Text(
                  'Release to add files or links',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.isDraft
                ? 'Resources are added when you save. Linked originals stay on this device.'
                : 'Attachments are saved with the task. Linked originals stay on this device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // Clean, responsive action buttons row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy || picking
                    ? null
                    : () => _pickFileOrFolder(TaskResourceKind.managed),
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Attach copy'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy || picking ? null : _attachFromSharedInbox,
                icon: const Icon(Icons.folder_shared_outlined, size: 16),
                label: const Text('From Shared Inbox'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : _addUrl,
                icon: const Icon(Icons.link, size: 16),
                label: const Text('Add URL'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              if (Platform.isWindows) ...[
                OutlinedButton.icon(
                  onPressed: busy || picking
                      ? null
                      : () => _pickFileOrFolder(TaskResourceKind.externalFile),
                  icon: const Icon(Icons.insert_drive_file_outlined, size: 16),
                  label: const Text('Link file'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy || picking
                      ? null
                      : () =>
                            _pickFileOrFolder(TaskResourceKind.externalFolder),
                  icon: const Icon(Icons.folder_outlined, size: 16),
                  label: const Text('Link folder'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: scheme.error, fontSize: 12)),
          ],
          if (!widget.isDraft && persistedResources == null) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (hasItems) const SizedBox(height: 10),
          // Draft items
          if (widget.isDraft)
            for (var i = 0; i < draftItems.length; i++) ...[
              _buildDraftRow(i, draftItems[i], scheme, theme),
              if (i < draftItems.length - 1) const Divider(height: 1),
            ],
          // Persisted items
          if (!widget.isDraft && persistedResources != null)
            for (var i = 0; i < persistedResources!.length; i++) ...[
              _buildPersistedRow(persistedResources![i], scheme, theme),
              if (i < persistedResources!.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }

  Widget _buildDraftRow(
    int index,
    DraftTaskResource item,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final subtaskIds =
        widget.resourceSubtaskMap?['draft_$index'] ?? const <String>[];
    final assignedSubtasks = widget.subtasks
        .where((s) => subtaskIds.contains(s.id))
        .toList();

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(
        _iconForKind(item.kind, item.target, item.label),
        size: 20,
        color: scheme.primary,
      ),
      title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: assignedSubtasks.isNotEmpty
          ? Wrap(
              spacing: 4,
              children: [
                for (final sub in assignedSubtasks)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    label: Text(
                      'Subtask: ${sub.title}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            )
          : null,
      trailing: PopupMenuButton<String>(
        tooltip: 'Resource actions',
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (action) {
          if (action == 'rename') _renameResource('$index', item.label);
          if (action == 'editUrl') _editUrl('$index', item.target);
          if (action == 'subtasks') _assignSubtasks('draft_$index', item.label);
          if (action == 'remove') {
            _removeResource('$index', item.label, item.kind);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          if (item.kind == TaskResourceKind.url)
            const PopupMenuItem(value: 'editUrl', child: Text('Edit URL')),
          if (widget.subtasks.isNotEmpty)
            const PopupMenuItem(
              value: 'subtasks',
              child: Text('Assign to Subtasks'),
            ),
          const PopupMenuItem(value: 'remove', child: Text('Remove')),
        ],
      ),
    );
  }

  Widget _buildPersistedRow(
    TaskResource resource,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final subtaskIds = persistedSubtaskMap[resource.id] ?? const <String>[];
    final assignedSubtasks = widget.subtasks
        .where((s) => subtaskIds.contains(s.id))
        .toList();

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(
        _iconForKind(resource.kind, resource.target, resource.label),
        size: 20,
        color: availability[resource.id] == false
            ? scheme.error
            : scheme.primary,
      ),
      title: InkWell(
        onTap: () => _openResource(resource),
        child: Text(
          resource.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: scheme.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
      subtitle: assignedSubtasks.isNotEmpty
          ? Wrap(
              spacing: 4,
              children: [
                for (final sub in assignedSubtasks)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    label: Text(
                      'Subtask: ${sub.title}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            )
          : null,
      trailing: PopupMenuButton<String>(
        tooltip: 'Resource actions',
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (action) {
          if (action == 'open') _openResource(resource);
          if (action == 'rename') _renameResource(resource.id, resource.label);
          if (action == 'editUrl') _editUrl(resource.id, resource.target ?? '');
          if (action == 'subtasks') {
            _assignSubtasks(resource.id, resource.label);
          }
          if (action == 'remove') {
            _removeResource(resource.id, resource.label, resource.kind);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'open', child: Text('Open')),
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          if (resource.kind == TaskResourceKind.url)
            const PopupMenuItem(value: 'editUrl', child: Text('Edit URL')),
          if (widget.subtasks.isNotEmpty)
            const PopupMenuItem(
              value: 'subtasks',
              child: Text('Assign to Subtasks'),
            ),
          const PopupMenuItem(value: 'remove', child: Text('Remove')),
        ],
      ),
    );
  }
}

bool _unsafeExtension(String extension) => const {
  '.exe',
  '.com',
  '.bat',
  '.cmd',
  '.ps1',
  '.psm1',
  '.vbs',
  '.vbe',
  '.js',
  '.jse',
  '.wsf',
  '.wsh',
  '.scr',
  '.msi',
  '.msp',
  '.lnk',
  '.url',
  '.scf',
  '.hta',
  '.cpl',
  '.reg',
}.contains(extension);
