import '../shared/app_spacing.dart';
import '../shared/app_section_heading.dart';
import '../../domain/focus_session.dart';
import 'time_tracking_dialog.dart';
import 'task_timer_intent.dart';
import '../shared/app_motion.dart';
import '../shared/scroll_edge_fade.dart';
import '../shared/status_snackbar.dart';
import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/time_tracking.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FocusWorkspace extends ConsumerStatefulWidget {
  const FocusWorkspace({super.key, required this.taskId, required this.onBack});

  final String taskId;
  final VoidCallback onBack;

  @override
  ConsumerState<FocusWorkspace> createState() => _FocusWorkspaceState();
}

class _FocusWorkspaceState extends ConsumerState<FocusWorkspace> {
  Timer? _ticker;
  late FocusSession _session;
  FocusMode get _mode => _session.mode;
  PomodoroPhase get _pomodoroPhase => _session.phase;
  int get _countdownMinutes => _session.countdownMinutes;
  set _countdownMinutes(int v) => _session.countdownMinutes = v;
  int get _pomodoroWorkMinutes => _session.workMinutes;
  set _pomodoroWorkMinutes(int v) => _session.workMinutes = v;
  int get _pomodoroShortBreakMinutes => _session.shortBreakMinutes;
  set _pomodoroShortBreakMinutes(int v) => _session.shortBreakMinutes = v;
  int get _pomodoroLongBreakMinutes => _session.longBreakMinutes;
  set _pomodoroLongBreakMinutes(int v) => _session.longBreakMinutes = v;
  int get _pomodoroLongBreakInterval => _session.longBreakInterval;
  set _pomodoroLongBreakInterval(int v) => _session.longBreakInterval = v;
  int get _countdownRemainingSeconds => _session.seconds;
  set _countdownRemainingSeconds(int v) => _session.seconds = v;
  bool get _countdownRunning => _session.running;
  bool _workLogExpanded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _session = ref.read(appControllerProvider).focusSessionFor(widget.taskId);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final active = ref.read(appControllerProvider).activeTimer;
      final isRunningTimer =
          active?.taskId == widget.taskId &&
          active?.state == TimerState.running;
      if (_session.running || isRunningTimer) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant FocusWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _session = ref.read(appControllerProvider).focusSessionFor(widget.taskId);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _setPomodoroPhase(PomodoroPhase phase) => _runAction(
    () => ref
        .read(appControllerProvider)
        .changeFocusPhase(widget.taskId, phase: phase),
  );

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showTransientStatus(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatSeconds(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    final h = m ~/ 60;
    if (h > 0) {
      final remM = m % 60;
      return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final task = controller.tasks
        .where((t) => t.id == widget.taskId)
        .firstOrNull;
    final subtasks = controller.tasks
        .where((t) => controller.taskParents[t.id] == widget.taskId)
        .toList();
    final completedSubtasks = subtasks
        .where((t) => t.status == TaskStatus.completed)
        .length;

    final activeRun = controller.activeTimer;
    if (activeRun?.taskId == widget.taskId &&
        (!activeRun!.canControl || activeRun.needsReview(DateTime.now()))) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: widget.onBack),
          title: const Text('Focus Session'),
        ),
        body: TimeTrackingDialog(taskId: widget.taskId),
      );
    }
    final isCurrentTaskTimer = activeRun?.taskId == widget.taskId;
    final isTimerRunning =
        isCurrentTaskTimer && activeRun?.state == TimerState.running;

    final allEntries = controller.timeEntries
        .where((e) => e.taskId == widget.taskId)
        .toList();
    final entries = allEntries.where((e) {
      if (e.endsAt != null && e.durationAt(DateTime.now()) <= Duration.zero) {
        return false; // Suppress meaningless zero-duration completed entries from the UI log
      }
      return true;
    }).toList();
    final totalDuration = TimeEntry.distinctDuration(
      allEntries,
      DateTime.now(),
    );

    // Timer elapsed for stopwatch
    final stopwatchDuration = isCurrentTaskTimer
        ? TimeEntry.distinctDuration(
            allEntries.where((e) => e.timerRunId == activeRun?.id),
            DateTime.now(),
          )
        : Duration.zero;

    // Determine circular progress and displayed time
    double progress = 0.0;
    String displayTime = '00:00';
    String stateLabel = 'READY';

    if (_mode == FocusMode.stopwatch) {
      displayTime = formatWorkClock(stopwatchDuration);
      stateLabel = isTimerRunning
          ? 'RUNNING'
          : (isCurrentTaskTimer && activeRun?.state == TimerState.paused
                ? 'PAUSED'
                : 'STOPPED');
    } else if (_mode == FocusMode.countdown) {
      displayTime = _formatSeconds(_countdownRemainingSeconds);
      stateLabel = _countdownRunning ? 'COUNTING DOWN' : 'PAUSED';
      final totalSec = _countdownMinutes * 60;
      progress = totalSec > 0
          ? (totalSec - _countdownRemainingSeconds) / totalSec
          : 0.0;
    } else if (_mode == FocusMode.pomodoro) {
      displayTime = _formatSeconds(_countdownRemainingSeconds);
      stateLabel = _pomodoroPhase == PomodoroPhase.work
          ? (_countdownRunning ? 'FOCUS' : 'PAUSED')
          : (_pomodoroPhase == PomodoroPhase.shortBreak
                ? 'SHORT BREAK'
                : 'LONG BREAK');
      final totalSec = switch (_pomodoroPhase) {
        PomodoroPhase.work => _pomodoroWorkMinutes * 60,
        PomodoroPhase.shortBreak => _pomodoroShortBreakMinutes * 60,
        PomodoroPhase.longBreak => _pomodoroLongBreakMinutes * 60,
      };
      progress = totalSec > 0
          ? (totalSec - _countdownRemainingSeconds) / totalSec
          : 0.0;
    }

    final theme = Theme.of(context);
    final playing = _isPlaying(isTimerRunning);
    final paused =
        !playing &&
        (isCurrentTaskTimer && activeRun?.state == TimerState.paused ||
            _mode != FocusMode.stopwatch && progress > 0);
    final state = switch (stateLabel) {
      'RUNNING' => 'Running',
      'COUNTING DOWN' => 'Counting down',
      'FOCUS' => 'Focus interval',
      'SHORT BREAK' => playing ? 'Short break' : 'Short break · paused',
      'LONG BREAK' => playing ? 'Long break' : 'Long break · paused',
      _ => paused ? 'Paused' : 'Ready',
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Return to tasks',
          icon: const BackButtonIcon(),
          onPressed: widget.onBack,
        ),
        title: const Text('Focus'),
        actions: [
          IconButton(
            tooltip: 'Timer settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _busy || _session.running
                ? null
                : () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.editorPageMaxWidth,
          ),
          child: FadingListView(
            padding: AppLayout.pageInsets,
            children: [
              Semantics(
                header: true,
                child: Tooltip(
                  message: task?.title ?? 'Unavailable task',
                  excludeFromSemantics: true,
                  child: Text(
                    task?.title ?? 'Unavailable task',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.section,
                ),
                child: Column(
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        state,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        displayTime,
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        semanticsLabel:
                            '${_mode == FocusMode.stopwatch ? 'Elapsed' : 'Remaining'} time, $displayTime',
                      ),
                    ),
                    if (_mode != FocusMode.stopwatch) ...[
                      const SizedBox(height: AppSpacing.related),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        semanticsLabel: 'Interval progress',
                      ),
                    ],
                    if (_mode == FocusMode.pomodoro) ...[
                      const SizedBox(height: AppSpacing.gap),
                      Text(
                        _pomodoroPhase == PomodoroPhase.work
                            ? 'Up next: $_pomodoroShortBreakMinutes min short break'
                            : 'Up next: $_pomodoroWorkMinutes min focus',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.content),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.gap,
                      runSpacing: AppSpacing.gap,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _togglePlayPause(controller, activeRun),
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          label: Text(
                            playing
                                ? 'Pause'
                                : paused && _mode == FocusMode.stopwatch
                                ? 'Resume'
                                : 'Start',
                          ),
                        ),
                        if (_mode != FocusMode.stopwatch)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _runAction(() async {
                                    await controller.pauseFocus(widget.taskId);
                                    _session.reset();
                                  }),
                            child: const Text('Reset timer'),
                          ),
                        if (_mode == FocusMode.pomodoro)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _runAction(() async {
                                    await controller.pauseFocus(widget.taskId);
                                    _session.finish();
                                  }),
                            child: const Text('Next interval'),
                          )
                        else if (isCurrentTaskTimer)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () =>
                                      _runAction(() => controller.stopTimer()),
                            child: const Text('Stop & commit session'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const AppSectionHeading('Timer mode'),
              Wrap(
                spacing: AppSpacing.gap,
                runSpacing: AppSpacing.small,
                children: [
                  _modeButton('Stopwatch', FocusMode.stopwatch),
                  _modeButton('Countdown', FocusMode.countdown),
                  _modeButton('Pomodoro', FocusMode.pomodoro),
                ],
              ),
              if (_mode == FocusMode.pomodoro) ...[
                const AppSectionHeading('Interval'),
                Wrap(
                  spacing: AppSpacing.gap,
                  runSpacing: AppSpacing.small,
                  children: [
                    _phaseButton(
                      'Focus (${_pomodoroWorkMinutes}m)',
                      PomodoroPhase.work,
                    ),
                    _phaseButton(
                      'Short break (${_pomodoroShortBreakMinutes}m)',
                      PomodoroPhase.shortBreak,
                    ),
                    _phaseButton(
                      'Long break (${_pomodoroLongBreakMinutes}m)',
                      PomodoroPhase.longBreak,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.content),
              if (subtasks.isNotEmpty) ...[
                AppSectionHeading(
                  'Subtask progress',
                  detail: '$completedSubtasks of ${subtasks.length} done',
                ),
                LinearProgressIndicator(
                  value: completedSubtasks / subtasks.length,
                  semanticsLabel: 'Subtasks complete',
                ),
                const SizedBox(height: AppSpacing.content),
              ],
              const Divider(),
              AppSectionHeading(
                'Work recorded',
                detail: formatWorkClock(totalDuration),
              ),
              ExpansionTile(
                initiallyExpanded: _workLogExpanded,
                onExpansionChanged: (exp) =>
                    setState(() => _workLogExpanded = exp),
                title: const Text('Work Log'),
                subtitle: Text(
                  '${entries.length} recorded session${entries.length == 1 ? '' : 's'}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (entries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'No work recorded yet. Time will appear here as sessions finish.',
                              ),
                            ),
                          )
                        else
                          for (final entry in entries)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                entry.source == TimeEntrySource.timer
                                    ? Icons.timer_outlined
                                    : Icons.edit_note_outlined,
                                size: 18,
                              ),
                              title: Text(
                                entry.endsAt == null
                                    ? 'Running'
                                    : entry
                                              .durationAt(DateTime.now())
                                              .inSeconds ==
                                          0
                                    ? '<1s'
                                    : formatWorkClock(
                                        entry.durationAt(DateTime.now()),
                                      ),
                              ),
                              subtitle: Text(
                                '${entry.source == TimeEntrySource.timer ? 'Timer' : 'Manual'} · '
                                '${_entryDate(context, entry.startsAt)}'
                                '${entry.endsAt != null ? ' – ${_entryDate(context, entry.endsAt!)}' : ' (ongoing)'}',
                              ),
                              trailing: entry.source == TimeEntrySource.manual
                                  ? IconButton(
                                      tooltip: 'Delete entry',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                      ),
                                      onPressed: () => _runAction(
                                        () => controller.clearManualTime(entry),
                                      ),
                                    )
                                  : null,
                            ),
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

  String _entryDate(BuildContext context, DateTime instant) {
    final local = instant.toLocal();
    final date = MaterialLocalizations.of(context).formatShortDate(local);
    return '$date · ${TimeOfDay.fromDateTime(local).format(context)}';
  }

  bool _isPlaying(bool isTimerRunning) {
    if (_mode == FocusMode.stopwatch) {
      return isTimerRunning;
    }
    return _countdownRunning;
  }

  Future<void> _togglePlayPause(
    AppController controller,
    TimerRun? activeRun,
  ) => _runAction(() async {
    if (activeRun != null && activeRun.taskId != widget.taskId) {
      await openTaskTimer(
        context,
        controller,
        widget.taskId,
        open: (taskId) {
          if (taskId != widget.taskId) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => FocusWorkspace(
                  taskId: taskId,
                  onBack: () => Navigator.pop(context),
                ),
              ),
            );
          }
        },
      );
    } else {
      await controller.toggleFocus(widget.taskId);
    }
  });

  Widget _modeButton(String label, FocusMode mode) => ChoiceChip(
    label: Text(label),
    selected: _mode == mode,
    onSelected: _busy
        ? null
        : (selected) {
            if (selected && _mode != mode) {
              _runAction(
                () => ref
                    .read(appControllerProvider)
                    .changeFocusPhase(
                      widget.taskId,
                      mode: mode,
                      phase: PomodoroPhase.work,
                    ),
              );
            }
          },
  );

  Widget _phaseButton(String label, PomodoroPhase phase) => ChoiceChip(
    label: Text(label),
    selected: _pomodoroPhase == phase,
    onSelected: _busy ? null : (_) => _setPomodoroPhase(phase),
  );

  void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Timer Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Countdown Duration'),
                DropdownButton<int>(
                  isExpanded: true,
                  value: _countdownMinutes,
                  items: [5, 10, 15, 20, 25, 30, 45, 60]
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text('${m}m')),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _countdownMinutes = val;
                        if (_mode == FocusMode.countdown &&
                            !_countdownRunning) {
                          _countdownRemainingSeconds = val * 60;
                        }
                      });
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Pomodoro Focus Duration'),
                DropdownButton<int>(
                  isExpanded: true,
                  value: _pomodoroWorkMinutes,
                  items: [15, 20, 25, 30, 45, 50, 60]
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text('${m}m')),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pomodoroWorkMinutes = val;
                        if (_mode == FocusMode.pomodoro &&
                            _pomodoroPhase == PomodoroPhase.work) {
                          _countdownRemainingSeconds = val * 60;
                        }
                      });
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Short Break Duration'),
                DropdownButton<int>(
                  isExpanded: true,
                  value: _pomodoroShortBreakMinutes,
                  items: [3, 5, 10, 15]
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text('${m}m')),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pomodoroShortBreakMinutes = val;
                        if (_mode == FocusMode.pomodoro &&
                            _pomodoroPhase == PomodoroPhase.shortBreak) {
                          _countdownRemainingSeconds = val * 60;
                        }
                      });
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Long Break Duration'),
                DropdownButton<int>(
                  isExpanded: true,
                  value: _pomodoroLongBreakMinutes,
                  items: [10, 15, 20, 30]
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text('${m}m')),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pomodoroLongBreakMinutes = val;
                        if (_mode == FocusMode.pomodoro &&
                            _pomodoroPhase == PomodoroPhase.longBreak) {
                          _countdownRemainingSeconds = val * 60;
                        }
                      });
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Long Break After'),
                DropdownButton<int>(
                  isExpanded: true,
                  value: _pomodoroLongBreakInterval,
                  items: [2, 3, 4, 5, 6]
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m cycles'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pomodoroLongBreakInterval = val;
                      });
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
