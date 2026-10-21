enum NewTaskPlannedDay { today, noDate }

enum CompositionTextDisplay { full, compact }

class TaskViewPreferences {
  const TaskViewPreferences({
    this.newTaskPlannedDay = NewTaskPlannedDay.today,
    this.keepCompletedVisible = false,
    this.spellCheckEnabled = true,
    this.compositionTextDisplay = CompositionTextDisplay.compact,
  });

  final NewTaskPlannedDay newTaskPlannedDay;
  final bool keepCompletedVisible;
  final bool spellCheckEnabled;
  final CompositionTextDisplay compositionTextDisplay;

  TaskViewPreferences copyWith({
    NewTaskPlannedDay? newTaskPlannedDay,
    bool? keepCompletedVisible,
    bool? spellCheckEnabled,
    CompositionTextDisplay? compositionTextDisplay,
  }) => TaskViewPreferences(
    newTaskPlannedDay: newTaskPlannedDay ?? this.newTaskPlannedDay,
    keepCompletedVisible: keepCompletedVisible ?? this.keepCompletedVisible,
    spellCheckEnabled: spellCheckEnabled ?? this.spellCheckEnabled,
    compositionTextDisplay:
        compositionTextDisplay ?? this.compositionTextDisplay,
  );
}
