import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/time_tracking.dart';
import '../shared/status_snackbar.dart';

class CompactTaskTimer extends ConsumerStatefulWidget {
  const CompactTaskTimer({super.key, required this.open});
  final ValueChanged<String> open;
  @override
  ConsumerState<CompactTaskTimer> createState() => _CompactTaskTimerState();
}

class _CompactTaskTimerState extends ConsumerState<CompactTaskTimer> {
  Timer? ticker;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final run = ref.read(appControllerProvider).activeTimer;
      if (mounted &&
          run?.state == TimerState.running &&
          run!.canControl &&
          !run.needsReview(DateTime.now())) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Future<void> action(bool stop) async {
    if (busy) return;
    setState(() => busy = true);
    final c = ref.read(appControllerProvider);
    try {
      final run = c.activeTimer;
      if (run == null) return;
      if (stop) {
        await c.stopTimer();
      } else {
        await c.toggleFocus(run.taskId!);
      }
    } catch (_) {
      await c.refresh();
      if (mounted) {
        showTransientStatus(
          context,
          'Open the timer to review its current state.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(appControllerProvider.select((c) => c.activeTimer));
    if (run == null) return const SizedBox.shrink();
    final timeEntries = ref.watch(
      appControllerProvider.select((c) => c.timeEntries),
    );
    final taskTitle = ref.watch(
      appControllerProvider.select(
        (c) =>
            c.tasks.where((task) => task.id == run.taskId).firstOrNull?.title,
      ),
    );
    final review = !run.canControl || run.needsReview(DateTime.now());
    final running = run.state == TimerState.running;
    final elapsed = TimeEntry.distinctDuration(
      timeEntries.where((entry) => entry.timerRunId == run.id),
      review ? run.lastSeenAt : DateTime.now(),
    );
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      title: Wrap(
        spacing: 8,
        children: [
          Text(
            review
                ? 'Review timer'
                : running
                ? 'Running'
                : 'Paused',
          ),
          Text(
            formatWorkClock(elapsed),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      subtitle: Text(
        taskTitle ?? 'Unavailable task',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: run.taskId == null ? null : () => widget.open(run.taskId!),
      trailing: review || run.taskId == null
          ? const Icon(Icons.info_outline)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: running ? 'Pause timer' : 'Resume timer',
                  onPressed: busy ? null : () => action(false),
                  icon: Icon(running ? Icons.pause : Icons.play_arrow),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Timer controls',
                  enabled: !busy,
                  onSelected: (value) => action(value == 'stop'),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(running ? 'Pause' : 'Resume'),
                    ),
                    const PopupMenuItem(value: 'stop', child: Text('Stop')),
                  ],
                ),
              ],
            ),
    );
  }
}
