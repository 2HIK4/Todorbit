enum FocusMode { stopwatch, countdown, pomodoro }

enum PomodoroPhase { work, shortBreak, longBreak }

/// Process-local interval state. Repository time entries remain the work ledger.
/// A monotonic clock preserves fractional seconds across pauses and navigation.
class FocusSession {
  FocusSession({Duration Function()? elapsed}) {
    final clock = Stopwatch()..start();
    _elapsed = elapsed ?? (() => clock.elapsed);
  }
  late final Duration Function() _elapsed;
  FocusMode mode = FocusMode.stopwatch;
  PomodoroPhase phase = PomodoroPhase.work;
  int cycles = 0;
  int countdownMinutes = 25,
      workMinutes = 25,
      shortBreakMinutes = 5,
      longBreakMinutes = 15,
      longBreakInterval = 4;
  Duration _remaining = const Duration(minutes: 25);
  Duration? _started;
  DateTime? workDeadline;
  bool get running => _started != null;
  bool get recordsWork =>
      mode != FocusMode.pomodoro || phase == PomodoroPhase.work;
  Duration get remaining {
    final value =
        _remaining - (running ? _elapsed() - _started! : Duration.zero);
    return value.isNegative ? Duration.zero : value;
  }

  int get seconds => (remaining.inMilliseconds / 1000).ceil();
  set seconds(int value) {
    _remaining = Duration(seconds: value);
    _started = null;
  }

  int get phaseMinutes => mode == FocusMode.countdown
      ? countdownMinutes
      : switch (phase) {
          PomodoroPhase.work => workMinutes,
          PomodoroPhase.shortBreak => shortBreakMinutes,
          PomodoroPhase.longBreak => longBreakMinutes,
        };
  void start() {
    _started ??= _elapsed();
  }

  void pause() {
    _remaining = remaining;
    _started = null;
  }

  void reset() {
    pause();
    _remaining = Duration(minutes: phaseMinutes);
    workDeadline = null;
  }

  void finish() {
    pause();
    if (mode == FocusMode.pomodoro) {
      if (phase == PomodoroPhase.work) {
        cycles++;
        phase = cycles % longBreakInterval == 0
            ? PomodoroPhase.longBreak
            : PomodoroPhase.shortBreak;
      } else {
        phase = PomodoroPhase.work;
      }
      reset();
    }
  }
}
