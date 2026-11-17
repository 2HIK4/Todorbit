enum NewTaskPlannedDay { today, noDate }

enum CompositionTextDisplay { full, compact }

class TaskViewPreferences {
  const TaskViewPreferences({
    this.newTaskPlannedDay = NewTaskPlannedDay.today,
    this.keepCompletedVisible = false,
    this.spellCheckEnabled = true,
    this.compositionTextDisplay = CompositionTextDisplay.compact,
    this.detailPresentation = 'sidePanel',
    this.hiddenStandardCategories = const {},
    this.hiddenStandardProjects = const {},
  });

  final NewTaskPlannedDay newTaskPlannedDay;
  final bool keepCompletedVisible;
  final bool spellCheckEnabled;
  final CompositionTextDisplay compositionTextDisplay;
  final String detailPresentation;
  final Set<String> hiddenStandardCategories;
  final Set<String> hiddenStandardProjects;

  bool get isFullPageDetails => detailPresentation == 'fullPage';

  TaskViewPreferences copyWith({
    NewTaskPlannedDay? newTaskPlannedDay,
    bool? keepCompletedVisible,
    bool? spellCheckEnabled,
    CompositionTextDisplay? compositionTextDisplay,
    String? detailPresentation,
    Set<String>? hiddenStandardCategories,
    Set<String>? hiddenStandardProjects,
  }) => TaskViewPreferences(
    newTaskPlannedDay: newTaskPlannedDay ?? this.newTaskPlannedDay,
    keepCompletedVisible: keepCompletedVisible ?? this.keepCompletedVisible,
    spellCheckEnabled: spellCheckEnabled ?? this.spellCheckEnabled,
    compositionTextDisplay:
        compositionTextDisplay ?? this.compositionTextDisplay,
    detailPresentation: detailPresentation ?? this.detailPresentation,
    hiddenStandardCategories:
        hiddenStandardCategories ?? this.hiddenStandardCategories,
    hiddenStandardProjects:
        hiddenStandardProjects ?? this.hiddenStandardProjects,
  );
}
