import 'package:flutter/material.dart';
import '../../data/shared_inbox_store.dart';
import '../../domain/shared_inbox_entry.dart';

/// Modal dialog allowing the user to select one or multiple files from the Shared Inbox
/// to attach as managed resources to a task.
class SharedInboxPickerDialog extends StatefulWidget {
  const SharedInboxPickerDialog({
    super.key,
    this.store,
    this.alreadyAttachedShas = const {},
  });

  final SharedInboxStore? store;
  final Set<String> alreadyAttachedShas;

  @override
  State<SharedInboxPickerDialog> createState() =>
      _SharedInboxPickerDialogState();
}

class _SharedInboxPickerDialogState extends State<SharedInboxPickerDialog> {
  late final SharedInboxStore store = widget.store ?? SharedInboxStore();
  final searchController = TextEditingController();

  List<SharedInboxEntry> entries = const [];
  bool loading = false;
  String? error;
  final selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _load() {
    try {
      final loaded = store.loadSync();
      if (!mounted) return;
      setState(() {
        entries = loaded;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Failed to load shared files: $e';
        loading = false;
      });
    }
  }

  List<SharedInboxEntry> get filteredEntries {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries
        .where((e) => e.displayName.toLowerCase().contains(query))
        .toList();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
    return Icons.insert_drive_file_outlined;
  }

  void _toggleSelectAll(List<SharedInboxEntry> selectable) {
    setState(() {
      final selectableIds = selectable
          .where((e) =>
              !widget.alreadyAttachedShas.contains(e.sha256) &&
              e.byteSize <= SharedInboxStore.maxAttachmentBytes)
          .map((e) => e.id)
          .toSet();

      if (selectedIds.containsAll(selectableIds) && selectableIds.isNotEmpty) {
        selectedIds.removeAll(selectableIds);
      } else {
        selectedIds.addAll(selectableIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed = filteredEntries;
    final attachableCount = displayed
        .where((e) =>
            !widget.alreadyAttachedShas.contains(e.sha256) &&
            e.byteSize <= SharedInboxStore.maxAttachmentBytes)
        .length;

    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.75 - media.viewInsets.bottom;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: maxHeight.clamp(320.0, 640.0),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.folder_shared_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attach from Shared Inbox',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Originals remain in Shared Inbox',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search field if multiple entries exist
              if (entries.length > 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Filter files...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

              // Select All toggle bar if attachable items exist
              if (attachableCount > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${selectedIds.length} selected',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: Icon(
                          selectedIds.length == attachableCount
                              ? Icons.deselect
                              : Icons.select_all,
                          size: 16,
                        ),
                        label: Text(
                          selectedIds.length == attachableCount
                              ? 'Deselect all'
                              : 'Select all',
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _toggleSelectAll(displayed),
                      ),
                    ],
                  ),
                ),

              // Main List
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Center(
                            child: Text(
                              error!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          )
                        : entries.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.inbox_outlined,
                                        size: 40,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Shared Inbox is empty',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Share files to Todorbit from external Android apps '
                                        'to make them available here.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : displayed.isEmpty
                                ? Center(
                                    child: Text(
                                      'No matching files',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  )
                                : ListView(
                                    children: [
                                      for (final entry in displayed)
                                        _pickerTile(context, entry),
                                    ],
                                  ),
              ),

              const SizedBox(height: 12),
              // Dialog Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.attach_file, size: 16),
                    label: Text(
                      selectedIds.isEmpty
                          ? 'Attach'
                          : 'Attach (${selectedIds.length})',
                    ),
                    onPressed: selectedIds.isEmpty
                        ? null
                        : () {
                            final chosen = entries
                                .where((e) => selectedIds.contains(e.id))
                                .toList();
                            Navigator.pop(context, chosen);
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerTile(BuildContext context, SharedInboxEntry entry) {
    final theme = Theme.of(context);
    final alreadyAttached = widget.alreadyAttachedShas.contains(entry.sha256);
    final exceedsLimit =
        entry.byteSize > SharedInboxStore.maxAttachmentBytes;
    final disabled = alreadyAttached || exceedsLimit;
    final selected = selectedIds.contains(entry.id);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: disabled
          ? null
          : () {
              setState(() {
                if (selected) {
                  selectedIds.remove(entry.id);
                } else {
                  selectedIds.add(entry.id);
                }
              });
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: disabled
                  ? null
                  : (val) {
                      setState(() {
                        if (val == true) {
                          selectedIds.add(entry.id);
                        } else {
                          selectedIds.remove(entry.id);
                        }
                      });
                    },
            ),
            Icon(
              _iconForEntry(entry),
              size: 20,
              color: disabled
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: disabled
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatSize(entry.byteSize),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: disabled
                              ? theme.colorScheme.outline
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (alreadyAttached) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• Already attached',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (exceedsLimit) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• Exceeds 16 MB limit',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
