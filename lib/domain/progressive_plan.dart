class ProgressivePlan {
  const ProgressivePlan({
    required this.familyId,
    required this.steps,
    required this.repeatAtEnd,
  });

  final String familyId;
  final List<String> steps;
  final bool repeatAtEnd;
}

class ProgressiveAssignment {
  const ProgressiveAssignment({
    required this.taskId,
    required this.title,
    required this.stepIndex,
    required this.carryForward,
    required this.manual,
  });

  final String taskId;
  final String? title;
  final int? stepIndex;
  final bool carryForward;
  final bool manual;
}
