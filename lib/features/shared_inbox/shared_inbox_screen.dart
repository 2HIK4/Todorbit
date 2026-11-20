import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/shared_inbox_store.dart';
import '../../domain/shared_inbox_entry.dart';
import '../shared/app_motion.dart';
import '../shared/status_snackbar.dart';
import '../../platform/platform_resource_dialog.dart';

enum SharedInboxCategory { all, pdfs, images, docs, other }

/// Screen displaying the Android Shared Files Inbox.
///
/// Accessible directly from the mobile navigation drawer. Allows browsing,
/// previewing, searching, and managing shared files.
class SharedInboxScreen extends StatefulWidget {
  const SharedInboxScreen({
    super.key,
    this.store,
    this.resourceDialog = const WindowsResourceDialog(),
  });

  final SharedInboxStore? store;
  final WindowsResourceDialog resourceDialog;

  @override
  State<SharedInboxScreen> createState() => _SharedInboxScreenState();
}

class _SharedInboxScreenState extends State<SharedInboxScreen> {
  late final SharedInboxStore store = widget.store ?? SharedInboxStore();
  final searchController = TextEditingController();

  late List<SharedInboxEntry> allEntries = store.usesAndroidStorage
      ? []
      : store.loadSync();
  late bool loading = store.usesAndroidStorage;
  String? errorMessage;

  bool selectionMode = false;
  final selectedIds = <String>{};
  SharedInboxCategory activeCategory = SharedInboxCategory.all;

  @override
  void initState() {
    super.initState();
    if (store.usesAndroidStorage) unawaited(_load());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loaded = store.usesAndroidStorage
          ? await store.load()
          : store.loadSync();
      if (!mounted) return;
      setState(() {
        allEntries = loaded;
        loading = false;
        errorMessage = null;
        // Clean selection of any removed IDs
        selectedIds.removeWhere((id) => !loaded.any((e) => e.id == id));
        if (selectedIds.isEmpty && selectionMode) {
          selectionMode = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to load shared files: $e';
        loading = false;
      });
    }
  }

  Future<void> _handleRefresh() => _load();

  List<SharedInboxEntry> get filteredEntries {
    final query = searchController.text.trim().toLowerCase();
    return allEntries.where((entry) {
      if (query.isNotEmpty &&
          !entry.displayName.toLowerCase().contains(query)) {
        return false;
      }
      switch (activeCategory) {
        case SharedInboxCategory.all:
          return true;
        case SharedInboxCategory.pdfs:
          return entry.mimeType == 'application/pdf' ||
              entry.displayName.toLowerCase().endsWith('.pdf');
        case SharedInboxCategory.images:
          return entry.mimeType.startsWith('image/');
        case SharedInboxCategory.docs:
          final name = entry.displayName.toLowerCase();
          return entry.mimeType.startsWith('text/') ||
              name.endsWith('.txt') ||
              name.endsWith('.md') ||
              name.endsWith('.doc') ||
              name.endsWith('.docx') ||
              name.endsWith('.xls') ||
              name.endsWith('.xlsx');
        case SharedInboxCategory.other:
          final isPdf =
              entry.mimeType == 'application/pdf' ||
              entry.displayName.toLowerCase().endsWith('.pdf');
          final isImg = entry.mimeType.startsWith('image/');
          final isDoc =
              entry.mimeType.startsWith('text/') ||
              entry.displayName.toLowerCase().endsWith('.txt') ||
              entry.displayName.toLowerCase().endsWith('.md') ||
              entry.displayName.toLowerCase().endsWith('.doc') ||
              entry.displayName.toLowerCase().endsWith('.docx');
          return !isPdf && !isImg && !isDoc;
      }
    }).toList();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today, $timeStr';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  IconData _iconForEntry(SharedInboxEntry entry) {
    final name = entry.displayName.toLowerCase();
    if (entry.mimeType == 'application/pdf' || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (entry.mimeType.startsWith('image/')) {
      return Icons.image_outlined;
    }
    if (entry.mimeType.startsWith('text/') ||
        name.endsWith('.txt') ||
        name.endsWith('.md') ||
        name.endsWith('.doc') ||
        name.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (entry.mimeType.startsWith('audio/') ||
        entry.mimeType.startsWith('video/')) {
      return Icons.play_circle_outline;
    }
    if (name.endsWith('.zip')) {
      return Icons.archive_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _iconColorForEntry(BuildContext context, SharedInboxEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    final name = entry.displayName.toLowerCase();
    if (entry.mimeType == 'application/pdf' || name.endsWith('.pdf')) {
      return scheme.error;
    }
    if (entry.mimeType.startsWith('image/')) {
      return scheme.primary;
    }
    if (entry.mimeType.startsWith('text/') ||
        name.endsWith('.txt') ||
        name.endsWith('.md') ||
        name.endsWith('.doc') ||
        name.endsWith('.docx')) {
      return scheme.secondary;
    }
    return scheme.onSurfaceVariant;
  }

  Future<void> _openFile(SharedInboxEntry entry) async {
    final file = entry.fileIn(store.directory);
    if (!await file.exists()) {
      if (mounted) {
        showTransientStatus(context, 'File is no longer available on disk');
      }
      _load();
      return;
    }

    try {
      await widget.resourceDialog.open(file.path);
    } catch (e) {
      if (mounted) {
        showTransientStatus(context, 'Could not open file: $e');
      }
    }
  }

  Future<void> _confirmDeleteSingle(SharedInboxEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete from Shared Inbox?'),
        content: Text(
          'Permanently remove "${entry.displayName}" from your Shared Inbox?\n\n'
          'Any copies already attached to tasks will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await store.deleteEntry(entry.id);
      } catch (_) {
        if (mounted) {
          showTransientStatus(context, 'Could not remove shared file');
        }
        return;
      }
      await _load();
      if (mounted) {
        showTransientStatus(context, 'Removed from Shared Inbox');
      }
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = selectedIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $count shared file${count == 1 ? '' : 's'}?'),
        content: Text(
          'Permanently delete $count selected file${count == 1 ? '' : 's'} from your Shared Inbox?\n\n'
          'Any copies already attached to tasks will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await store.deleteEntries(selectedIds.toList());
      } catch (_) {
        if (mounted) {
          showTransientStatus(context, 'Could not remove shared files');
        }
        return;
      }
      if (!mounted) return;
      selectedIds.clear();
      selectionMode = false;
      await _load();
      if (mounted) {
        showTransientStatus(
          context,
          'Removed $count file${count == 1 ? '' : 's'} from Shared Inbox',
        );
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) {
          selectionMode = false;
        }
      } else {
        selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final currentFiltered = filteredEntries;
    setState(() {
      if (selectedIds.length == currentFiltered.length) {
        selectedIds.clear();
        selectionMode = false;
      } else {
        selectedIds.clear();
        selectedIds.addAll(currentFiltered.map((e) => e.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed = filteredEntries;
    final totalBytes = allEntries.fold<int>(0, (sum, e) => sum + e.byteSize);

    return Scaffold(
      appBar: AppBar(
        title: selectionMode
            ? Text('${selectedIds.length} selected')
            : const Text('Shared Files'),
        leading: selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel selection',
                onPressed: () => setState(() {
                  selectionMode = false;
                  selectedIds.clear();
                }),
              )
            : null,
        actions: [
          if (selectionMode) ...[
            IconButton(
              icon: Icon(
                selectedIds.length == displayed.length && displayed.isNotEmpty
                    ? Icons.deselect_outlined
                    : Icons.select_all_outlined,
              ),
              tooltip:
                  selectedIds.length == displayed.length && displayed.isNotEmpty
                  ? 'Deselect all'
                  : 'Select all',
              onPressed: displayed.isEmpty ? null : _toggleSelectAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete selected',
              onPressed: selectedIds.isEmpty ? null : _confirmDeleteSelected,
            ),
          ] else ...[
            if (allEntries.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.checklist_outlined),
                tooltip: 'Select files',
                onPressed: () => setState(() => selectionMode = true),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _load,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          if (allEntries.isNotEmpty || searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search shared files...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

          // Filter chips
          if (allEntries.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _filterChip(
                    SharedInboxCategory.all,
                    'All (${allEntries.length})',
                  ),
                  const SizedBox(width: 8),
                  _filterChip(SharedInboxCategory.pdfs, 'PDFs'),
                  const SizedBox(width: 8),
                  _filterChip(SharedInboxCategory.images, 'Images'),
                  const SizedBox(width: 8),
                  _filterChip(SharedInboxCategory.docs, 'Documents'),
                  const SizedBox(width: 8),
                  _filterChip(SharedInboxCategory.other, 'Other'),
                ],
              ),
            ),

          // Metadata stats banner
          if (allEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${allEntries.length} file${allEntries.length == 1 ? '' : 's'} • ${_formatSize(totalBytes)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message:
                        'Files in the Shared Inbox are stored locally on this device. '
                        'They are not included in cloud sync or database backups until attached to a task.',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 13,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'On-device only · Not synced',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Main list content
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: displayed.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: _emptyView(context),
                                  ),
                                ),
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            children: [
                              for (final entry in displayed)
                                _inboxItemCard(context, entry),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(SharedInboxCategory category, String label) {
    final active = activeCategory == category;
    return FilterChip(
      selected: active,
      label: Text(label),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => activeCategory = category),
    );
  }

  Widget _emptyView(BuildContext context) {
    final theme = Theme.of(context);
    final isFiltered =
        allEntries.isNotEmpty && searchController.text.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered
                  ? Icons.search_off_outlined
                  : Icons.folder_shared_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No matching shared files' : 'No shared files yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try adjusting your search query or category filter.'
                  : 'Files and PDFs shared to Todorbit from other Android apps '
                        'will appear here so you can attach them to tasks later.\n\n'
                        'Sharing files does not automatically create tasks.\n\n'
                        'Files remain local to this device and are excluded from '
                        'cloud sync and backups until attached to a task.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inboxItemCard(BuildContext context, SharedInboxEntry entry) {
    final theme = Theme.of(context);
    final selected = selectedIds.contains(entry.id);
    final iconColor = _iconColorForEntry(context, entry);
    final isOverAttachmentLimit =
        entry.byteSize > SharedInboxStore.maxAttachmentBytes;

    return Card(
      key: ValueKey(entry.id),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (selectionMode) {
            _toggleSelection(entry.id);
          } else {
            _openFile(entry);
          }
        },
        onLongPress: () {
          if (!selectionMode) {
            setState(() {
              selectionMode = true;
              selectedIds.add(entry.id);
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => _toggleSelection(entry.id),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconForEntry(entry), color: iconColor, size: 22),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _formatSize(entry.byteSize),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '•',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Text(
                          _formatDate(entry.receivedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isOverAttachmentLimit)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '>16 MB (Preview only)',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectionMode)
                PopupMenuButton<String>(
                  tooltip: 'File actions',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) {
                    if (action == 'open') _openFile(entry);
                    if (action == 'delete') _confirmDeleteSingle(entry);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new, size: 18),
                          SizedBox(width: 8),
                          Text('Open / Preview'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
