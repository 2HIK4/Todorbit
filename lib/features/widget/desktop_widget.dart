import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';

/// Small second-process UI used only for desktop attachment feasibility.
/// Native runner owns positioning and attachment; this widget owns data actions.
class DesktopWidgetApp extends StatelessWidget {
  const DesktopWidgetApp({super.key, required this.onExit, this.onOpenApp});
  final Future<void> Function() onExit;
  final Future<void> Function()? onOpenApp;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Life Manager Widget',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5365B5)),
    ),
    home: _DesktopWidgetHome(onExit: onExit, onOpenApp: onOpenApp),
  );
}

class _DesktopWidgetHome extends ConsumerStatefulWidget {
  const _DesktopWidgetHome({required this.onExit, this.onOpenApp});
  final Future<void> Function() onExit;
  final Future<void> Function()? onOpenApp;

  @override
  ConsumerState<_DesktopWidgetHome> createState() => _DesktopWidgetHomeState();
}

class _DesktopWidgetHomeState extends ConsumerState<_DesktopWidgetHome> {
  final input = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Widget action failed: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _add() async {
    final title = input.text.trim();
    if (title.isEmpty) return;
    await _run(() async {
      await ref
          .read(appControllerProvider)
          .addTask(
            TaskDraft(title: title, scheduledDate: localDate(DateTime.now())),
          );
      input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final today = localDate(DateTime.now());
    final tasks = controller.tasks
        .where(
          (task) =>
              task.isOpen &&
              (task.scheduledDate == today || task.categoryId == null),
        )
        .take(20)
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Life Manager',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: busy ? null : () => _run(controller.refresh),
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Open main app',
                    onPressed: () => _run(widget.onOpenApp ?? _openMainApp),
                    icon: const Icon(Icons.open_in_new, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Close widget',
                    onPressed: widget.onExit,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              Text(
                '$today · Today and Inbox',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(child: Text('No tasks for today or Inbox'))
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: false,
                            title: Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: busy
                                ? null
                                : (_) => _run(
                                    () => controller.setComplete(task, true),
                                  ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(
                        hintText: 'Add a task for today',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add task',
                    onPressed: busy ? null : _add,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMainApp() async {
    await Process.start(
      Platform.resolvedExecutable,
      const [],
      mode: ProcessStartMode.detached,
    );
  }
}
