import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/focus_session.dart';

void main() {
  test('pause preserves fractions and excludes paused time', () {
    var now = Duration.zero;
    final s = FocusSession(elapsed: () => now)..mode = FocusMode.countdown;
    s.seconds = 5;
    s.start();
    now += const Duration(milliseconds: 750);
    s.pause();
    expect(s.remaining, const Duration(milliseconds: 4250));
    now += const Duration(hours: 2);
    s.start();
    now += const Duration(milliseconds: 250);
    s.pause();
    expect(s.remaining, const Duration(seconds: 4));
  });
  test(
    'Pomodoro work and breaks advance ready without auto-recording work',
    () {
      var now = Duration.zero;
      final s = FocusSession(elapsed: () => now)..mode = FocusMode.pomodoro;
      s.workMinutes = 1;
      s.longBreakInterval = 2;
      s.reset();
      s.start();
      now += const Duration(minutes: 2);
      expect(s.remaining, Duration.zero);
      s.finish();
      expect(s.phase, PomodoroPhase.shortBreak);
      expect(s.running, false);
      expect(s.recordsWork, false);
      s.start();
      now += const Duration(minutes: 5);
      s.finish();
      expect(s.phase, PomodoroPhase.work);
      expect(s.running, false);
      s.start();
      now += const Duration(minutes: 1);
      s.finish();
      expect(s.phase, PomodoroPhase.longBreak);
      expect(s.cycles, 2);
    },
  );
}
