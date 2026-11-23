import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/time_tracking.dart';
import 'alarm_indicator.dart';
import 'app_spacing.dart';
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

    final theme = Theme.of(context);
    final compact = theme.visualDensity == VisualDensity.compact;
    return _TaskRowSurface(
      highlighted: _isTimerActive || isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 48 : 52),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.gap,
              vertical: compact ? 0 : AppSpacing.small,
            ),
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
                if (iconKey != null)
                  Icon(
                    iconForKey(iconKey, Icons.task_alt_outlined),
                    size: 19,
                    color: scheme.onSurfaceVariant,
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                      if (_hasDesktopBadges)
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

  bool get _hasDesktopBadges {
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
    final style = Theme.of(context).textTheme.bodySmall;

    if (subtaskProgress != null && subtaskProgress!.total > 0) {
      badges.add(
        Text(
          'Subtasks ${subtaskProgress!.completed}/${subtaskProgress!.total}',
          style: style,
        ),
      );
    }

    if (checklistProgress != null && checklistProgress!.total > 0) {
      badges.add(
        Text(
          'Checklist ${checklistProgress!.completed}/${checklistProgress!.total}',
          style: style,
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
          style: style?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
      );
    }

    if (task.scheduledDate != null) {
      badges.add(Text('Plan ${task.scheduledDate}', style: style));
    }

    if (task.deadlineDate != null) {
      badges.add(
        Text(
          'Due ${task.deadlineDate}',
          style: style?.copyWith(
            color: overdue ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (task.status == TaskStatus.waiting || task.status == TaskStatus.onHold) {
      badges.add(
        Text(
          task.status == TaskStatus.waiting ? 'Waiting' : 'On hold',
          style: style,
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
            style: style?.copyWith(color: scheme.error),
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
    final status = switch (task.status) {
      TaskStatus.notStarted => null,
      TaskStatus.inProgress => 'In progress',
      TaskStatus.waiting => 'Waiting',
      TaskStatus.onHold => 'On hold',
      TaskStatus.completed => 'Completed',
      TaskStatus.cancelled => 'Cancelled',
    };
    if (status != null) addPart(TextSpan(text: status));
    if (_isTimerActive) {
      addPart(
        TextSpan(
          text: timerState == TimerState.running
              ? 'Timer running'
              : 'Timer paused',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
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

    return _TaskRowSurface(
      highlighted: _isTimerActive || isSelected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: ListTile(
          selected: isSelected,
          contentPadding: const EdgeInsetsDirectional.only(
            start: AppSpacing.small,
            end: AppSpacing.gap,
          ),
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
                    style: Theme.of(context).textTheme.bodySmall,
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

class _TaskRowSurface extends StatelessWidget {
  const _TaskRowSurface({required this.highlighted, required this.child});

  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: highlighted ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: child,
        ),
        const Divider(height: 1),
      ],
    );
  }
}
