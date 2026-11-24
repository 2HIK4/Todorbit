import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';

Future<void> seedRefinementRows(LifeRepository repo, DateTime today) async {
  final category = await repo.addCategory('Product studio');
  final projects = [
    await repo.addProject(category.id, 'Autumn release'),
    await repo.addProject(category.id, 'Research and operations'),
  ];
  const subjects = [
    'Review onboarding feedback and prioritize follow-up with the design team',
    'Send accessibility findings to the release team',
    'Prepare contracts and budget for the next planning meeting',
    'Check outstanding questions before the customer demo',
    'Review shared documentation and update the rollout checklist',
    'Verify prototype behavior with long labels and enlarged text',
  ];
  for (var i = 0; i < 132; i++) {
    final day = today.add(Duration(days: i % 15));
    final task = await repo.addTask(
      TaskDraft(
        title: '${subjects[i % subjects.length]} · ${i + 1}',
        categoryId: i % 7 == 0 ? null : category.id,
        projectId: i % 7 == 0 ? null : projects[i % projects.length].id,
        scheduledDate: i % 7 == 0 ? null : localDate(day),
        deadlineDate: i % 3 == 0
            ? localDate(day.add(const Duration(days: 2)))
            : null,
        priority: i % 4,
        plannedDurationMinutes: i % 3 == 0 ? 45 : null,
      ),
    );
    if (i < 4) {
      await repo.addSubtask(task, const TaskDraft(title: 'Review the draft'));
      await repo.addChecklistItem(task.id, 'Check the acceptance criteria');
    }
  }
  for (var i = 0; i < 12; i++) {
    final planned = localDate(today.add(Duration(days: i % 3)));
    await repo.addRecurringTask(
      TaskDraft(title: 'Weekly handoff ${i + 1}', scheduledDate: planned),
      RecurrenceRule(kind: RecurrenceKind.weekly, startDate: planned),
    );
  }
  for (var i = 0; i < 90; i++) {
    final day = today.add(Duration(days: i ~/ 10 - 3));
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      9 + (i % 10) ~/ 2,
      15 * (i % 2),
    );
    await repo.addEvent(
      EventDraft(
        title: 'Studio ${subjects[i % subjects.length]}',
        startsAt: start,
        endsAt: start.add(const Duration(minutes: 75)),
        colorValue: const [0xFF2563EB, 0xFF0D9488, 0xFF7C3AED][i % 3],
      ),
    );
  }
}
