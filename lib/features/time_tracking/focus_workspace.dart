import '../../domain/focus_session.dart';
import 'time_tracking_dialog.dart';
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
      final isRunningTimer = active?.taskId == widget.taskId &&
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
      progress = (stopwatchDuration.inSeconds % 3600) / 3600.0;
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

    const deepBackground = Color(0xFF161320);
    const purpleAccent = Color(0xFF8B5CF6);
    const breakAccent = Color(0xFF38BDF8);

    final activeAccent =
        (_mode == FocusMode.pomodoro && _pomodoroPhase != PomodoroPhase.work)
        ? breakAccent
        : purpleAccent;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: deepBackground,
        colorScheme: Theme.of(context).colorScheme
            .copyWith(surface: deepBackground, primary: activeAccent),
      ),
      child: Scaffold(
        backgroundColor: deepBackground,
        appBar: AppBar(
          backgroundColor: deepBackground,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Return to tasks',
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: widget.onBack,
          ),
          title: Text(
            task?.title ?? 'Focus Session',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Timer settings',
              icon: const Icon(Icons.settings_outlined, color: Colors.white70),
              onPressed: _busy || _session.running
                  ? null
                  : () => _showSettingsDialog(context),
            ),
          ],
        ),
        body: FadingListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            // Mode Selector Pills
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF221E33),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    _modeButton('Stopwatch', FocusMode.stopwatch, purpleAccent),
                    _modeButton('Countdown', FocusMode.countdown, purpleAccent),
                    _modeButton('Pomodoro', FocusMode.pomodoro, purpleAccent),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pomodoro phase selector (when in Pomodoro mode)
            if (_mode == FocusMode.pomodoro) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C182B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      _phaseButton(
                        'Focus (${_pomodoroWorkMinutes}m)',
                        PomodoroPhase.work,
                        purpleAccent,
                      ),
                      _phaseButton(
                        'Short Break (${_pomodoroShortBreakMinutes}m)',
                        PomodoroPhase.shortBreak,
                        breakAccent,
                      ),
                      _phaseButton(
                        'Long Break (${_pomodoroLongBreakMinutes}m)',
                        PomodoroPhase.longBreak,
                        breakAccent,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Subtask Progress (if subtasks exist)
            if (subtasks.isNotEmpty) ...[
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF221E33),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtask progress',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '$completedSubtasks of ${subtasks.length} done',
                            style: const TextStyle(
                              color: purpleAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: subtasks.isEmpty
                              ? 0
                              : completedSubtasks / subtasks.length,
                          backgroundColor: const Color(0xFF332D4C),
                          valueColor: const AlwaysStoppedAnimation(
                            purpleAccent,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Circular Timer Widget matching reference designs
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer background disc
                    Container(
                      width: 270,
                      height: 270,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1D192C),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    // Progress ring
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFF2B2540),
                        valueColor: AlwaysStoppedAnimation(activeAccent),
                      ),
                    ),
                    // Digital Time Readout and state
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stateLabel,
                          style: TextStyle(
                            color: activeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // "Up next" preview in Pomodoro mode
            if (_mode == FocusMode.pomodoro)
              Center(
                child: Text(
                  _pomodoroPhase == PomodoroPhase.work
                      ? 'Up next: ${_pomodoroShortBreakMinutes.toString().padLeft(2, '0')}:00 Short Break'
                      : 'Up next: ${_pomodoroWorkMinutes.toString().padLeft(2, '0')}:00 Focus',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),

            const SizedBox(height: 20),

            // Primary Control Buttons (Play/Pause, Reset, Skip, Stop)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reset Button
                  IconButton.filledTonal(
                    tooltip: 'Reset timer',
                    onPressed: _busy || _mode == FocusMode.stopwatch
                        ? null
                        : () => _runAction(() async {
                            await controller.pauseFocus(widget.taskId);
                            _session.reset();
                          }),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF29243E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.refresh, size: 22),
                  ),

                  const SizedBox(width: 16),

                  // Main Play / Pause Button
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _togglePlayPause(controller, activeRun),
                    style: FilledButton.styleFrom(
                      backgroundColor: activeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPlaying(isTimerRunning)
                              ? Icons.pause
                              : Icons.play_arrow,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPlaying(isTimerRunning) ? 'Pause' : 'Start',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Skip / Next Button (or Stop)
                  if (_mode == FocusMode.pomodoro)
                    IconButton.filledTonal(
                      tooltip: 'Next interval',
                      onPressed: _busy
                          ? null
                          : () => _runAction(() async {
                              await controller.pauseFocus(widget.taskId);
                              _session.finish();
                            }),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF29243E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      icon: const Icon(Icons.skip_next, size: 22),
                    )
                  else
                    IconButton.filledTonal(
                      tooltip: 'Stop & commit session',
                      onPressed: isCurrentTaskTimer
                          ? () => _runAction(() => controller.stopTimer())
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF29243E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      icon: const Icon(Icons.stop, size: 22),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Total time recorded today banner
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF201B31),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF322B4A)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: purpleAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total recorded: ${formatWorkClock(totalDuration)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Collapsible Work Log (Collapsed by default per Requirement 16)
            Card(
              margin: EdgeInsets.zero,
              color: const Color(0xFF1E1A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF2F2948)),
              ),
              child: ExpansionTile(
                initiallyExpanded: _workLogExpanded,
                onExpansionChanged: (exp) =>
                    setState(() => _workLogExpanded = exp),
                title: const Text(
                  'Work Log',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${entries.length} recorded session${entries.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
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
                                color: purpleAccent,
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${entry.source == TimeEntrySource.timer ? 'Timer' : 'Manual'} · '
                                '${entry.startsAt.toLocal().toString().split('.').first}'
                                '${entry.endsAt != null ? ' – ${entry.endsAt!.toLocal().toString().split('.').first}' : ' (ongoing)'}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: entry.source == TimeEntrySource.manual
                                  ? IconButton(
                                      tooltip: 'Delete entry',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: Colors.white54,
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
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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
  ) => _runAction(() => controller.toggleFocus(widget.taskId));

  Widget _modeButton(String label, FocusMode mode, Color accent) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: _busy || selected
          ? null
          : () => _runAction(
              () => ref
                  .read(appControllerProvider)
                  .changeFocusPhase(
                    widget.taskId,
                    mode: mode,
                    phase: PomodoroPhase.work,
                  ),
            ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _phaseButton(String label, PomodoroPhase phase, Color accent) {
    final selected = _pomodoroPhase == phase;
    return GestureDetector(
      onTap: _busy ? null : () => _setPomodoroPhase(phase),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: selected ? Border.all(color: accent, width: 1) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white60,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF221E33),
        title: const Text(
          'Timer Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Countdown Duration',
                style: TextStyle(color: Colors.white),
              ),
              trailing: DropdownButton<int>(
                dropdownColor: const Color(0xFF2A253F),
                value: _countdownMinutes,
                style: const TextStyle(color: Colors.white),
                items: [5, 10, 15, 20, 25, 30, 45, 60]
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text('${m}m')),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _countdownMinutes = val;
                      if (_mode == FocusMode.countdown && !_countdownRunning) {
                        _countdownRemainingSeconds = val * 60;
                      }
                    });
                    Navigator.pop(ctx);
                  }
                },
              ),
            ),
            ListTile(
              title: const Text(
                'Pomodoro Focus Duration',
                style: TextStyle(color: Colors.white),
              ),
              trailing: DropdownButton<int>(
                dropdownColor: const Color(0xFF2A253F),
                value: _pomodoroWorkMinutes,
                style: const TextStyle(color: Colors.white),
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
            ),
            ListTile(
              title: const Text(
                'Short Break Duration',
                style: TextStyle(color: Colors.white),
              ),
              trailing: DropdownButton<int>(
                dropdownColor: const Color(0xFF2A253F),
                value: _pomodoroShortBreakMinutes,
                style: const TextStyle(color: Colors.white),
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
            ),
            ListTile(
              title: const Text(
                'Long Break Duration',
                style: TextStyle(color: Colors.white),
              ),
              trailing: DropdownButton<int>(
                dropdownColor: const Color(0xFF2A253F),
                value: _pomodoroLongBreakMinutes,
                style: const TextStyle(color: Colors.white),
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
            ),
            ListTile(
              title: const Text(
                'Long Break After',
                style: TextStyle(color: Colors.white),
              ),
              trailing: DropdownButton<int>(
                dropdownColor: const Color(0xFF2A253F),
                value: _pomodoroLongBreakInterval,
                style: const TextStyle(color: Colors.white),
                items: [2, 3, 4, 5, 6]
                    .map(
                      (m) =>
                          DropdownMenuItem(value: m, child: Text('$m cycles')),
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
