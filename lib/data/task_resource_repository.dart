part of 'life_repository.dart';

extension TaskResourceRepository on LifeRepository {
  static const maxAttachmentBytes = 16 * 1024 * 1024;

  Future<List<TaskResource>> taskResources(String taskId) async {
    final rows = await db
        .customSelect(
          'SELECT id,task_id,kind,label,target,original_name,byte_size,sha256,created_at,updated_at '
          'FROM task_resources WHERE task_id=? ORDER BY created_at,id',
          variables: [Variable.withString(taskId)],
        )
        .get();
    return rows
        .map(
          (row) => TaskResource(
            id: row.read<String>('id'),
            taskId: row.read<String>('task_id'),
            kind: TaskResourceKind.values.byName(row.read<String>('kind')),
            label: row.read<String>('label'),
            target: row.readNullable<String>('target'),
            originalName: row.readNullable<String>('original_name'),
            byteSize: row.readNullable<int>('byte_size'),
            sha256: row.readNullable<String>('sha256'),
            createdAt: DateTime.parse(row.read<String>('created_at')),
            updatedAt: DateTime.parse(row.read<String>('updated_at')),
          ),
        )
        .toList();
  }

  Future<TaskResource> attachManagedFile(String taskId, File source) async {
    final entityType = await FileSystemEntity.type(
      source.path,
      followLinks: false,
    );
    if (entityType != FileSystemEntityType.file) {
      throw ArgumentError('Choose a regular file');
    }
    final before = await source.stat();
    if (before.size > maxAttachmentBytes) {
      throw ArgumentError('Attachments must be 16 MB or smaller');
    }
    final bytes = await source.readAsBytes();
    final after = await source.stat();
    if (bytes.length > maxAttachmentBytes ||
        before.size != bytes.length ||
        after.size != bytes.length ||
        before.modified != after.modified) {
      throw StateError('File changed while being attached');
    }
    final name = path.basename(source.path);
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(name)) {
      throw ArgumentError('Invalid attachment filename');
    }
    final digest = sha256.convert(bytes).toString();
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction(() async {
      await _requireActiveTask(taskId);
      await db.customInsert(
        'INSERT INTO task_resources(id,task_id,kind,label,content,byte_size,sha256,original_name,created_at,updated_at) '
        'VALUES(?,?,?,?,?,?,?,?,?,?)',
        variables: [
          Variable.withString(id),
          Variable.withString(taskId),
          Variable.withString(TaskResourceKind.managed.name),
          Variable.withString(name),
          Variable.withBlob(bytes),
          Variable.withInt(bytes.length),
          Variable.withString(digest),
          Variable.withString(name),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    });
    return (await taskResources(taskId)).firstWhere((item) => item.id == id);
  }

  Future<TaskResource> addExternalResource(
    String taskId,
    TaskResourceKind kind,
    String target, {
    String? label,
  }) async {
    if (kind == TaskResourceKind.managed) {
      throw ArgumentError('Use attachManagedFile for copied files');
    }
    final cleaned = target.trim();
    if (cleaned.isEmpty) throw ArgumentError('Resource target is required');
    String stored;
    int? size;
    if (kind == TaskResourceKind.url) {
      final uri = Uri.tryParse(cleaned);
      if (uri == null ||
          !uri.hasScheme ||
          uri.scheme.length < 2 ||
          const {
            'file',
            'javascript',
            'data',
            'vbscript',
            'shell',
          }.contains(uri.scheme.toLowerCase()) ||
          ((uri.scheme == 'http' || uri.scheme == 'https') &&
              uri.host.isEmpty)) {
        throw ArgumentError('Enter a valid website or application link');
      }
      stored = uri.toString();
    } else {
      final entity = FileSystemEntity.typeSync(cleaned, followLinks: false);
      final expected = kind == TaskResourceKind.externalFile
          ? FileSystemEntityType.file
          : FileSystemEntityType.directory;
      if (entity != expected) {
        throw ArgumentError('Selected file or folder is unavailable');
      }
      stored = path.normalize(path.absolute(cleaned));
      if (kind == TaskResourceKind.externalFile) {
        size = File(stored).lengthSync();
      }
    }
    final display =
        (label ??
                (kind == TaskResourceKind.url ? stored : path.basename(stored)))
            .trim();
    if (display.isEmpty) throw ArgumentError('Resource label is required');
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction(() async {
      await _requireActiveTask(taskId);
      await db.customInsert(
        'INSERT INTO task_resources(id,task_id,kind,label,target,byte_size,created_at,updated_at) '
        'VALUES(?,?,?,?,?,?,?,?)',
        variables: [
          Variable.withString(id),
          Variable.withString(taskId),
          Variable.withString(kind.name),
          Variable.withString(display),
          Variable.withString(stored),
          Variable<int>(size),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    });
    return (await taskResources(taskId)).firstWhere((item) => item.id == id);
  }

  Future<void> renameTaskResource(TaskResource resource, String label) async {
    final cleaned = label.trim();
    if (cleaned.isEmpty) throw ArgumentError('Resource label is required');
    final changed = await db.customUpdate(
      'UPDATE task_resources SET label=?,updated_at=? WHERE id=? AND updated_at=?',
      variables: [
        Variable.withString(cleaned),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(resource.id),
        Variable.withString(resource.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (changed != 1) {
      throw StateError('Resource changed; reload and try again');
    }
  }

  Future<void> updateTaskUrl(TaskResource resource, String target) async {
    if (resource.kind != TaskResourceKind.url) throw ArgumentError('Not a URL');
    final uri = Uri.tryParse(target.trim());
    if (uri == null ||
        !uri.hasScheme ||
        uri.scheme.length < 2 ||
        const {
          'file',
          'javascript',
          'data',
          'vbscript',
          'shell',
        }.contains(uri.scheme.toLowerCase()) ||
        ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty)) {
      throw ArgumentError('Enter a valid website or application link');
    }
    final changed = await db.customUpdate(
      'UPDATE task_resources SET target=?,updated_at=? WHERE id=? AND updated_at=?',
      variables: [
        Variable.withString(uri.toString()),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(resource.id),
        Variable.withString(resource.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (changed != 1) {
      throw StateError('Resource changed; reload and try again');
    }
  }

  Future<void> removeTaskResource(TaskResource resource) async {
    final changed = await db.customUpdate(
      'DELETE FROM task_resources WHERE id=? AND updated_at=?',
      variables: [
        Variable.withString(resource.id),
        Variable.withString(resource.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (changed != 1) {
      throw StateError('Resource changed; reload and try again');
    }
  }

  Future<List<int>> managedAttachmentBytes(TaskResource resource) async {
    if (resource.kind != TaskResourceKind.managed) {
      throw ArgumentError('Resource is not a managed attachment');
    }
    final row = await db
        .customSelect(
          'SELECT content,byte_size,sha256 FROM task_resources WHERE id=? AND kind=?',
          variables: [
            Variable.withString(resource.id),
            Variable.withString(TaskResourceKind.managed.name),
          ],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Attachment is unavailable');
    final bytes = row.read<List<int>>('content');
    if (bytes.length != row.read<int>('byte_size') ||
        sha256.convert(bytes).toString() != row.read<String>('sha256')) {
      throw StateError('Attachment failed integrity verification');
    }
    return bytes;
  }
}
