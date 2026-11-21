import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/time_tracking.dart';
import 'alarm_indicator.dart';
import 'app_theme_tokens.dart';
import 'icon_picker.dart';

/// Progress summary for nested subtasks or checklist items.
@immutable
class TaskProgress {
  const TaskProgress({required this.completed, required this.total});

  final int completed;
  final int total;
}

/// Visual presentation variant for [AppTaskRow].
enum AppTaskRowVariant {
  desktop,
  mobile,
}

/// A canonical, reusable task list row component for desktop and mobile surfaces.
///
/// Encapsulates presentation, completion toggle semantics, overdue highlighting,
/// priority color coding, and responsive layout variants while keeping domain state,
/// database queries, and navigation handling in caller controllers.
class AppTaskRow extends StatelessWidget {
  const AppTaskRow({
    super.key,
    required this.task,
    this.variant,
    this.isSelected = false,
    this.timerState,
    this.hasAlarm = false,
    this.iconKey,
    this.categoryName,
    this.projectName,
    this.subtaskProgress,
    this.checklistProgress,
    this.unmetPrerequisitesCount = 0,
    this.unmetPrerequisitesSummary,
    this.onTap,
    this.onToggleComplete,
    this.onLongPress,
    this.quickStartAction,
    this.trailingActions,
  });

  final LifeTask task;
  final AppTaskRowVariant? variant;
  final bool isSelected;
  final TimerState? timerState;
  final bool hasAlarm;
  final String? iconKey;
  final String? categoryName;
  final String? projectName;
  final TaskProgress? subtaskProgress;
  final TaskProgress? checklistProgress;
  final int unmetPrerequisitesCount;
  final String? unmetPrerequisitesSummary;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleComplete;
  final VoidCallback? onLongPress;
  final Widget? quickStartAction;
  final Widget? trailingActions;

  bool get _isTimerActive =>
      timerState == TimerState.running || timerState == TimerState.paused;

  @override
  Widget build(BuildContext context) {
    final effectiveVariant = variant ??
        (Theme.of(context).platform == TargetPlatform.android
            ? AppTaskRowVariant.mobile
            : AppTaskRowVariant.desktop);

    return switch (effectiveVariant) {
      AppTaskRowVariant.desktop => _buildDesktop(context),
      AppTaskRowVariant.mobile => _buildMobile(context),
    };
  }

  Widget _buildDesktop(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TodorbitThemeTokens>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? TodorbitThemeTokens.dark()
            : TodorbitThemeTokens.light());
    final done = task.status == TaskStatus.completed;
    final today = localDate(DateTime.now());
    final overdue = task.isOpen &&
        task.deadlineDate != null &&
        task.deadlineDate!.compareTo(today) < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: _isTimerActive
          ? scheme.primaryContainer.withValues(alpha: 0.7)
          : isSelected
              ? scheme.secondaryContainer.withValues(alpha: 0.55)
              : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Tooltip(
                  message: done ? 'Reopen task' : 'Complete task',
                  child: Checkbox(
                    value: done,
                    semanticLabel:
                        '${done ? 'Reopen' : 'Complete'} ${task.title}',
                    onChanged: onToggleComplete != null
                        ? (value) => onToggleComplete!(value ?? false)
                        : null,
                  ),
                ),
                Icon(
                  iconForKey(
                    iconKey,
                    Icons.task_alt_outlined,
                  ),
                  size: 19,
                  color: scheme.primary,
                ),
                if (task.isOpen && hasAlarm)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: AlarmIndicator(),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? scheme.onSurface.withValues(alpha: 0.55)
                              : null,
                        ),
                      ),
                      if (_hasDesktopBadges(overdue))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: _buildDesktopBadges(
                              context,
                              scheme,
                              overdue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (task.priority >= 2)
                  Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: tokens.colorForPriority(task.priority),
                  ),
                ?quickStartAction,
                ?trailingActions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasDesktopBadges(bool overdue) {
    return task.scheduledDate != null ||
        task.deadlineDate != null ||
        task.status == TaskStatus.inProgress ||
        _isTimerActive ||
        (subtaskProgress != null && subtaskProgress!.total > 0) ||
        (checklistProgress != null && checklistProgress!.total > 0) ||
        task.status == TaskStatus.waiting ||
        task.status == TaskStatus.onHold ||
        unmetPrerequisitesCount > 0;
  }

  List<Widget> _buildDesktopBadges(
    BuildContext context,
    ColorScheme scheme,
    bool overdue,
  ) {
    final badges = <Widget>[];

    if (subtaskProgress != null && subtaskProgress!.total > 0) {
      badges.add(
        Text(
          'Subtasks ${subtaskProgress!.completed}/${subtaskProgress!.total}',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (checklistProgress != null && checklistProgress!.total > 0) {
      badges.add(
        Text(
          'Checklist ${checklistProgress!.completed}/${checklistProgress!.total}',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_isTimerActive || task.status == TaskStatus.inProgress) {
      badges.add(
        Text(
          switch (timerState) {
            TimerState.running => 'Timer running',
            TimerState.paused => 'Timer paused',
            TimerState.stopped || null => 'In progress',
          },
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
      );
    }

    if (task.scheduledDate != null) {
      badges.add(
        Text(
          'Plan ${task.scheduledDate}',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (task.deadlineDate != null) {
      badges.add(
        Text(
          'Due ${task.deadlineDate}',
          style: TextStyle(
            fontSize: 12,
            color: overdue ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (task.status == TaskStatus.waiting || task.status == TaskStatus.onHold) {
      badges.add(
        Text(
          task.status == TaskStatus.waiting ? 'Waiting' : 'On hold',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (unmetPrerequisitesCount > 0) {
      badges.add(
        Tooltip(
          message: unmetPrerequisitesSummary ??
              'Blocked by $unmetPrerequisitesCount prerequisite(s)',
          child: Text(
            'Blocked by $unmetPrerequisitesCount',
            style: TextStyle(
              fontSize: 12,
              color: scheme.error,
            ),
          ),
        ),
      );
    }

    return badges;
  }

  Widget _buildMobile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = task.status == TaskStatus.completed;
    final today = localDate(DateTime.now());
    final overdue = task.isOpen &&
        task.deadlineDate != null &&
        task.deadlineDate!.compareTo(today) < 0;

    final subtitleParts = <InlineSpan>[];
    void addPart(InlineSpan span) {
      if (subtitleParts.isNotEmpty) {
        subtitleParts.add(const TextSpan(text: ' · '));
      }
      subtitleParts.add(span);
    }

    if (task.priority > 0) {
      addPart(TextSpan(text: 'Priority ${task.priority}'));
    }
    if (task.status != TaskStatus.notStarted) {
      addPart(TextSpan(text: task.status.name));
    }
    if (task.scheduledDate != null) {
      final parsed = DateTime.tryParse(task.scheduledDate!);
      final formatted = parsed != null
          ? MaterialLocalizations.of(context).formatMediumDate(parsed)
          : task.scheduledDate!;
      addPart(TextSpan(text: 'Planned $formatted'));
    }
    if (task.deadlineDate != null) {
      final parsed = DateTime.tryParse(task.deadlineDate!);
      final formatted = parsed != null
          ? MaterialLocalizations.of(context).formatMediumDate(parsed)
          : task.deadlineDate!;
      addPart(
        TextSpan(
          text: overdue ? 'Overdue · Due $formatted' : 'Due $formatted',
          style: overdue
              ? TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                )
              : null,
        ),
      );
    }
    if (categoryName != null) {
      addPart(TextSpan(text: categoryName!));
    }
    if (projectName != null) {
      addPart(TextSpan(text: projectName!));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: ListTile(
          contentPadding: const EdgeInsetsDirectional.only(start: 6, end: 8),
          leading: Checkbox(
            value: done,
            semanticLabel: '${done ? 'Reopen' : 'Complete'} ${task.title}',
            onChanged: onToggleComplete != null
                ? (value) => onToggleComplete!(value == true)
                : null,
          ),
          title: Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: done
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: subtitleParts.isEmpty
              ? null
              : Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    children: subtitleParts,
                  ),
                ),
          onTap: onTap,
          onLongPress: onLongPress,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (overdue)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.error,
                    size: 20,
                    semanticLabel: 'Overdue',
                  ),
                ),
              if (task.isOpen && hasAlarm) const AlarmIndicator(),
              ?trailingActions,
            ],
          ),
        ),
      ),
    );
  }
}
