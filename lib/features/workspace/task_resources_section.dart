import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../data/app_database.dart';
import '../../data/life_repository.dart';
import '../../domain/task_resources.dart';
import 'windows_resource_dialog.dart';

class TaskResourcesSection extends StatefulWidget {
  const TaskResourcesSection({
    super.key,
    required this.taskId,
    required this.repository,
    this.dialog = const WindowsResourceDialog(),
  });

  final String taskId;
  final LifeRepository repository;
  final WindowsResourceDialog dialog;

  @override
  State<TaskResourcesSection> createState() => _TaskResourcesSectionState();
}

class _TaskResourcesSectionState extends State<TaskResourcesSection> {
  static const _dropChannel = MethodChannel('life_manager/file_drop');
  final _dropArea = GlobalKey();
  bool dropAvailable = false;
  bool dropHover = false;
  List<TaskResource>? resources;
  final availability = <String, bool>{};
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
    if (Platform.isWindows) {
      _dropChannel.setMethodCallHandler(_handleDropEvent);
      _dropChannel
          .invokeMethod<bool>('available')
          .then((available) {
            if (mounted) setState(() => dropAvailable = available == true);
          })
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) _dropChannel.setMethodCallHandler(null);
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
    if (call.method != 'drop' || !inside || busy) return;
    final arguments = call.arguments;
    final raw = arguments is Map ? arguments['files'] : null;
    if (raw is! List) return;
    final paths = raw.whereType<String>().toList();
    if (paths.isEmpty) return;
    await _acceptDrop(paths);
  }

  Future<void> _acceptDrop(List<String> paths) async {
    final unique = <String, String>{};
    for (final entered in paths) {
      final absolute = path.normalize(path.absolute(entered));
      unique[absolute.toLowerCase()] = absolute;
    }
    try {
      for (final file in unique.values) {
        if (await FileSystemEntity.type(file, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError(
            'Dropped file is missing, inaccessible, or unsupported: $file',
          );
        }
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
      return;
    }
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add ${unique.length} file${unique.length == 1 ? '' : 's'}?',
        ),
        content: const Text(
          'Attach stores portable copies in the task database. Link keeps files at their original location on this computer.',
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
    await _run(() async {
      final existingLinks = (resources ?? const <TaskResource>[])
          .where((item) => item.kind == TaskResourceKind.externalFile)
          .map(
            (item) => path.normalize(path.absolute(item.target!)).toLowerCase(),
          )
          .toSet();
      for (final file in unique.values) {
        if (choice == 'link') {
          if (existingLinks.contains(file.toLowerCase())) continue;
          await widget.repository.addExternalResource(
            widget.taskId,
            TaskResourceKind.externalFile,
            file,
          );
        } else {
          await widget.repository.attachManagedFile(widget.taskId, File(file));
        }
      }
    });
  }

  Future<void> _reload() async {
    try {
      final loaded = await widget.repository.taskResources(widget.taskId);
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
          resources = loaded;
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
      await _reload();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _textDialog(
    String title,
    String initial,
    String label,
  ) async {
    var value = initial;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          onChanged: (text) => value = text,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addUrl() async {
    final entered = await _textDialog(
      'Add URL',
      '',
      'Website or application link',
    );
    if (entered == null) return;
    await _run(() async {
      await widget.repository.addExternalResource(
        widget.taskId,
        TaskResourceKind.url,
        entered,
      );
    });
  }

  Future<void> _open(TaskResource resource) async {
    await _run(() async {
      if (resource.kind == TaskResourceKind.managed) {
        final extension = path
            .extension(resource.originalName ?? '')
            .toLowerCase();
        if (extension.isNotEmpty &&
            !RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension)) {
          throw StateError('Attachment type cannot be opened here');
        }
        if (_unsafeExtension(extension)) {
          throw StateError(
            'Executable or shortcut attachments cannot be opened here',
          );
        }
        final bytes = await widget.repository.managedAttachmentBytes(resource);
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
        await widget.dialog.open(target.path);
        return;
      }
      final target = resource.target!;
      if (resource.kind == TaskResourceKind.url) {
        final scheme = Uri.parse(target).scheme.toLowerCase();
        if (scheme != 'http' && scheme != 'https') {
          final approved = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Open application link?'),
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
      await widget.dialog.open(target);
    });
  }

  Future<void> _remove(TaskResource resource) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove task resource?'),
        content: Text(
          resource.kind == TaskResourceKind.managed
              ? 'The stored copy of ${resource.label} will be removed from this task.'
              : 'The link to ${resource.label} will be removed. The external file or folder will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (approved == true) {
      await _run(() => widget.repository.removeTaskResource(resource));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    key: _dropArea,
    decoration: BoxDecoration(
      border: Border.all(
        color: dropHover
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        width: 2,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resources', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (dropAvailable && dropHover)
          Text(
            'Release to add files',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      final file = await widget.dialog.chooseFile();
                      if (file != null) {
                        await widget.repository.attachManagedFile(
                          widget.taskId,
                          file,
                        );
                      }
                    }),
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Attach'),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      final file = await widget.dialog.chooseFile();
                      if (file != null) {
                        await widget.repository.addExternalResource(
                          widget.taskId,
                          TaskResourceKind.externalFile,
                          file.path,
                        );
                      }
                    }),
              icon: const Icon(Icons.insert_drive_file_outlined, size: 18),
              label: const Text('Link file'),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      final folder = await widget.dialog.chooseFolder();
                      if (folder != null) {
                        await widget.repository.addExternalResource(
                          widget.taskId,
                          TaskResourceKind.externalFolder,
                          folder.path,
                        );
                      }
                    }),
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text('Link folder'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : _addUrl,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('URL'),
            ),
          ],
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (resources == null) const LinearProgressIndicator(),
        for (final resource in resources ?? <TaskResource>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(resource.label),
            subtitle: Text(
              '${_kindLabel(resource.kind)} · ${_resourceStatus(resource)}'
              '${resource.byteSize == null
                  ? ''
                  : resource.kind == TaskResourceKind.managed
                  ? ' · ${resource.byteSize} bytes'
                  : ' · ${resource.byteSize} bytes when linked'}',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Resource actions for ${resource.label}',
              enabled: !busy,
              onSelected: (action) async {
                if (action == 'open') await _open(resource);
                if (action == 'remove') await _remove(resource);
                if (action == 'rename') {
                  final label = await _textDialog(
                    'Rename resource',
                    resource.label,
                    'Label',
                  );
                  if (label != null) {
                    await _run(
                      () =>
                          widget.repository.renameTaskResource(resource, label),
                    );
                  }
                }
                if (action == 'edit') {
                  final target = await _textDialog(
                    'Edit URL',
                    resource.target!,
                    'URL',
                  );
                  if (target != null) {
                    await _run(
                      () => widget.repository.updateTaskUrl(resource, target),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'open', child: Text('Open')),
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename label'),
                ),
                if (resource.kind == TaskResourceKind.url)
                  const PopupMenuItem(value: 'edit', child: Text('Edit URL')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ),
      ],
    ),
  );

  String _resourceStatus(TaskResource resource) => switch (resource.kind) {
    TaskResourceKind.managed => 'Stored',
    TaskResourceKind.url => 'Availability checked when opened',
    _ =>
      availability[resource.id] == true
          ? 'Available'
          : 'Unavailable or inaccessible',
  };
}

String _kindLabel(TaskResourceKind kind) => switch (kind) {
  TaskResourceKind.managed => 'Attachment',
  TaskResourceKind.externalFile => 'External file',
  TaskResourceKind.externalFolder => 'External folder',
  TaskResourceKind.url => 'URL',
};

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
