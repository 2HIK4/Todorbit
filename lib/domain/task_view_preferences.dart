enum NewTaskPlannedDay { today, noDate }

class TaskViewPreferences {
  const TaskViewPreferences({
    this.newTaskPlannedDay = NewTaskPlannedDay.today,
    this.keepCompletedVisible = false,
    this.spellCheckEnabled = true,
  });

  final NewTaskPlannedDay newTaskPlannedDay;
  final bool keepCompletedVisible;
  final bool spellCheckEnabled;

  TaskViewPreferences copyWith({
    NewTaskPlannedDay? newTaskPlannedDay,
    bool? keepCompletedVisible,
    bool? spellCheckEnabled,
  }) => TaskViewPreferences(
    newTaskPlannedDay: newTaskPlannedDay ?? this.newTaskPlannedDay,
    keepCompletedVisible: keepCompletedVisible ?? this.keepCompletedVisible,
    spellCheckEnabled: spellCheckEnabled ?? this.spellCheckEnabled,
  );
}
