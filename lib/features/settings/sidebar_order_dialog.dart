import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../shared/sidebar_items.dart';

class SidebarOrderDialog extends ConsumerStatefulWidget {
  const SidebarOrderDialog({super.key});

  @override
  ConsumerState<SidebarOrderDialog> createState() => _SidebarOrderDialogState();
}

class _SidebarOrderDialogState extends ConsumerState<SidebarOrderDialog> {
  late List<WorkspaceView> order;

  @override
  void initState() {
    super.initState();
    order = List.of(ref.read(appControllerProvider).sidebarOrder);
  }

  Future<void> _save(List<WorkspaceView> next) async {
    try {
      await ref.read(appControllerProvider).setSidebarOrder(next);
      if (mounted) setState(() => order = next);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save sidebar order: $error')),
        );
      }
    }
  }

  void _move(int from, int to) {
    final next = List<WorkspaceView>.of(order);
    final item = next.removeAt(from);
    next.insert(to, item);
    _save(next);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 460,
        maxHeight: MediaQuery.sizeOf(context).height - 48,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sidebar order',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text('Drag a row, or use the arrow buttons to move it.'),
            const SizedBox(height: 12),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: order.length,
                onReorderItem: _move,
                itemBuilder: (context, index) {
                  final view = order[index];
                  return ListTile(
                    key: ValueKey(view),
                    dense: true,
                    leading: Icon(sidebarIcon(view)),
                    title: Text(sidebarName(view)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Move ${sidebarName(view)} up',
                          onPressed: index == 0
                              ? null
                              : () => _move(index, index - 1),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        IconButton(
                          tooltip: 'Move ${sidebarName(view)} down',
                          onPressed: index == order.length - 1
                              ? null
                              : () => _move(index, index + 1),
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(
                            Icons.drag_handle,
                            semanticLabel: 'Drag to reorder',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    _save(List.of(AppController.defaultSidebarOrder)),
                child: const Text('Reset to default'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
