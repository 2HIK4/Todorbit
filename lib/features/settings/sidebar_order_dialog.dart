import '../shared/scroll_edge_fade.dart';
import '../shared/app_motion.dart';
import '../search/advanced_search_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../shared/sidebar_items.dart';
import '../../domain/settings_history.dart';
import '../shared/settings_history_scope.dart';

class SidebarOrderDialog extends ConsumerStatefulWidget {
  const SidebarOrderDialog({super.key});

  @override
  ConsumerState<SidebarOrderDialog> createState() => _SidebarOrderDialogState();
}

class _SidebarOrderDialogState extends ConsumerState<SidebarOrderDialog> {
  late List<WorkspaceView> order;
  final history = SettingsHistory<List<WorkspaceView>>(
    equal: (a, b) =>
        a.length == b.length &&
        List.generate(a.length, (i) => a[i] == b[i]).every((v) => v),
  );
  bool busy = false;
  void travel(bool redo) {
    if (busy) return;
    _save(redo ? history.redo(order) : history.undo(order), record: false);
  }

  @override
  void initState() {
    super.initState();
    order = List.of(ref.read(appControllerProvider).sidebarOrder);
  }

  Future<void> _save(List<WorkspaceView> next, {bool record = true}) async {
    if (busy) return;
    busy = true;
    final previous = List<WorkspaceView>.of(order);
    try {
      await ref.read(appControllerProvider).setSidebarOrder(next);
      if (record) history.record(previous, List.unmodifiable(next));
      if (mounted) setState(() => order = next);
    } catch (error) {
      history.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save sidebar order: $error')),
        );
      }
    } finally {
      busy = false;
    }
  }

  void _move(int from, int to) {
    final next = List<WorkspaceView>.of(order);
    final item = next.removeAt(from);
    next.insert(to, item);
    _save(next);
  }

  Future<void> visibility(String id, bool visible) async {
    final c = ref.read(appControllerProvider);
    final hidden = {...c.hiddenNavigation};
    visible ? hidden.remove(id) : hidden.add(id);
    await navigationSave(hidden: hidden);
  }

  Future<void> customMove(int from, int to) async {
    final custom = ref
        .read(appControllerProvider)
        .orderedSavedViews
        .map((v) => v.id)
        .toList();
    custom.insert(to, custom.removeAt(from));
    await navigationSave(order: custom);
  }

  Future<void> navigationSave({
    Set<String>? hidden,
    List<String>? order,
  }) async {
    try {
      await ref
          .read(appControllerProvider)
          .setNavigationState(hidden: hidden, customOrder: order);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save navigation: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SettingsHistoryScope(
    undo: () => travel(false),
    redo: () => travel(true),
    child: Dialog(
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
                      'Customize navigation',
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
              const Text(
                'Show, hide or reorder views. Settings and customization remain available.',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ScrollEdgeFade(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    itemCount:
                        order.length +
                        ref
                            .watch(appControllerProvider)
                            .orderedSavedViews
                            .length +
                        2,
                    onReorderItem: (from, to) {
                      if (from < order.length && to < order.length) {
                        _move(from, to);
                      }
                    },
                    itemBuilder: (context, index) {
                      final c = ref.watch(appControllerProvider);
                      final custom = c.orderedSavedViews;
                      if (index >= order.length + custom.length) {
                        final view = [
                          WorkspaceView.reports,
                          WorkspaceView.contributors,
                        ][index - order.length - custom.length];
                        return CheckboxListTile(
                          key: ValueKey('optional:${view.name}'),
                          value: !c.hiddenNavigation.contains(view.name),
                          title: Text(sidebarName(view)),
                          onChanged: (visible) =>
                              visibility(view.name, visible == true),
                        );
                      }
                      if (index >= order.length) {
                        final custom = c.orderedSavedViews;
                        final i = index - order.length;
                        final saved = custom[i];
                        return ListTile(
                          key: ValueKey(saved.id),
                          leading: Checkbox(
                            value: !c.hiddenNavigation.contains(saved.id),
                            onChanged: (visible) =>
                                visibility(saved.id, visible == true),
                          ),
                          title: Text(saved.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Move ${saved.name} up',
                                icon: const Icon(Icons.keyboard_arrow_up),
                                onPressed: i == 0
                                    ? null
                                    : () => customMove(i, i - 1),
                              ),
                              IconButton(
                                tooltip: 'Move ${saved.name} down',
                                icon: const Icon(Icons.keyboard_arrow_down),
                                onPressed: i == custom.length - 1
                                    ? null
                                    : () => customMove(i, i + 1),
                              ),
                              IconButton(
                                tooltip: 'Delete ${saved.name}',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    animationStyle: AppMotion.style(context),
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete saved view?'),
                                      content: Text(
                                        'Delete ${saved.name}? Tasks and events are kept.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete view'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    try {
                                      await c.deleteSavedView(saved);
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not delete view: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }
                      final view = order[index];
                      final buttons = Row(
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
                        ],
                      );
                      final drag = ReorderableDragStartListener(
                        index: index,
                        child: const Icon(
                          Icons.drag_handle,
                          semanticLabel: 'Drag to reorder',
                        ),
                      );
                      return LayoutBuilder(
                        key: ValueKey(view),
                        builder: (context, bounds) {
                          final compact =
                              bounds.maxWidth < 380 ||
                              MediaQuery.textScalerOf(context).scale(14) > 20;
                          final tile = ListTile(
                            dense: true,
                            leading: Checkbox(
                              value: !c.hiddenNavigation.contains(view.name),
                              onChanged: (visible) =>
                                  visibility(view.name, visible == true),
                            ),
                            title: Text(sidebarName(view)),
                            trailing: compact
                                ? SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Center(child: drag),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [buttons, drag],
                                  ),
                          );
                          return compact
                              ? Column(
                                  children: [
                                    tile,
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: buttons,
                                    ),
                                  ],
                                )
                              : tile;
                        },
                      );
                    },
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add category / project view'),
                onPressed: () => showDialog<void>(
                  context: context,
                  animationStyle: AppMotion.style(context),
                  builder: (_) =>
                      const AdvancedSearchDialog(creatingSavedView: true),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await _save(List.of(AppController.defaultSidebarOrder));
                    await navigationSave(hidden: {}, order: []);
                    if (mounted) setState(() {});
                  },
                  child: const Text('Reset to default'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
