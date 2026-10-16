import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';

/// Small second-process UI used only for desktop attachment feasibility.
/// Native runner owns positioning and attachment; this widget owns data actions.
class DesktopWidgetApp extends StatelessWidget {
  const DesktopWidgetApp({
    super.key,
    required this.onExit,
    this.onOpenApp,
    this.diagnostics = false,
    this.diagnosticsDirectory,
  });
  final Future<void> Function() onExit;
  final Future<void> Function()? onOpenApp;
  final bool diagnostics;
  final Directory? diagnosticsDirectory;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Life Manager Widget',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5365B5)),
    ),
    home: _DesktopWidgetHome(
      onExit: onExit,
      onOpenApp: onOpenApp,
      diagnostics: diagnostics,
      diagnosticsDirectory: diagnosticsDirectory,
    ),
  );
}

class _DesktopWidgetHome extends ConsumerStatefulWidget {
  const _DesktopWidgetHome({
    required this.onExit,
    this.onOpenApp,
    required this.diagnostics,
    this.diagnosticsDirectory,
  });
  final Future<void> Function() onExit;
  final Future<void> Function()? onOpenApp;
  final bool diagnostics;
  final Directory? diagnosticsDirectory;

  @override
  ConsumerState<_DesktopWidgetHome> createState() => _DesktopWidgetHomeState();
}

class _DesktopWidgetHomeState extends ConsumerState<_DesktopWidgetHome>
    with WidgetsBindingObserver {
  final input = TextEditingController();
  final inputFocus = FocusNode();
  _WidgetFocusLog? focusLog;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode && widget.diagnostics) {
      focusLog = _WidgetFocusLog.start(directory: widget.diagnosticsDirectory);
      WidgetsBinding.instance.addObserver(this);
      inputFocus.addListener(_logFocus);
      _logFocus();
    }
  }

  void _logFocus() {
    focusLog?.write(
      'input-focus hasFocus=${inputFocus.hasFocus} '
      'primary=${inputFocus.hasPrimaryFocus} '
      'lifecycle=${WidgetsBinding.instance.lifecycleState}',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    focusLog?.write('lifecycle=$state inputHasFocus=${inputFocus.hasFocus}');
  }

  @override
  void dispose() {
    if (focusLog != null) {
      inputFocus.removeListener(_logFocus);
      WidgetsBinding.instance.removeObserver(this);
      focusLog?.write('widget disposed');
    }
    inputFocus.dispose();
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
                    onPressed: () => _run(() async {
                      focusLog?.write('open-app requested');
                      await (widget.onOpenApp ?? _openMainApp)();
                      focusLog?.write('open-app launch returned');
                    }),
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
                      focusNode: inputFocus,
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
    final process = await Process.start(
      Platform.resolvedExecutable,
      const [],
      mode: ProcessStartMode.detached,
    );
    focusLog?.write('main process started pid=${process.pid}');
  }
}

class _WidgetFocusLog {
  _WidgetFocusLog(this.file);

  final File file;

  static _WidgetFocusLog? start({Directory? directory}) {
    try {
      if (directory == null) {
        final appData = Platform.environment['APPDATA'];
        if (appData == null) return null;
        directory = Directory('$appData\\Life Manager\\logs');
      }
      directory.createSync(recursive: true);
      final log = _WidgetFocusLog(
        File('${directory.path}\\widget-flutter-diagnostics-$pid.log'),
      );
      log.write('Flutter focus diagnostics started; no task text is logged');
      return log;
    } on FileSystemException {
      return null;
    }
  }

  void write(String event) {
    try {
      if (file.existsSync() && file.lengthSync() >= 2 * 1024 * 1024) {
        file.writeAsStringSync('');
      }
      file.writeAsStringSync(
        '${DateTime.now().toIso8601String()} pid=$pid $event\n',
        mode: FileMode.append,
      );
    } on FileSystemException {
      // Diagnostics must never make the widget unusable.
    }
  }
}
