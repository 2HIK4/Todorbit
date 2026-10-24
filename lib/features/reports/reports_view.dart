import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
import '../shared/about_view_button.dart';
import '../shared/anchored_select_field.dart';

enum _Period { week, month, quarter, custom }

class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  _Period period = _Period.month;
  DateTimeRange? customRange;

  Future<void> _setPeriod(_Period next) async {
    if (next != _Period.custom) {
      setState(() => period = next);
      return;
    }
    final today = DateTime.now();
    final chosen = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange:
          customRange ??
          DateTimeRange(
            start: today.subtract(const Duration(days: 29)),
            end: today,
          ),
      helpText: 'Report date range (up to 366 days)',
    );
    if (chosen == null) return;
    if (chosen.duration.inDays > 365) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a range of at most 366 days.')),
        );
      }
      return;
    }
    setState(() {
      customRange = chosen;
      period = _Period.custom;
    });
  }

  String _duration(Duration value) {
    final minutes = value.inMinutes;
    final hours = minutes ~/ 60;
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes % 60}m';
  }

  Widget _metric(String label, String value, String detail, IconData icon) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final today = localDate(DateTime.now());
    final through = period == _Period.custom && customRange != null
        ? localDate(customRange!.end)
        : today;
    final from = switch (period) {
      _Period.week => RecurrenceRule.shiftDate(through, -6),
      _Period.month => RecurrenceRule.shiftDate(through, -29),
      _Period.quarter => RecurrenceRule.shiftDate(through, -89),
      _Period.custom =>
        customRange == null
            ? RecurrenceRule.shiftDate(through, -29)
            : localDate(customRange!.start),
    };
    final report = controller.report(from, through);
    final maxCompleted = math.max(
      1,
      report.days.map((day) => day.completed).fold(0, math.max),
    );
    final projectNames = {
      for (final project in controller.projects) project.id: project.name,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 30),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              'Statistics and reports',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const AboutViewButton(
              description: 'Review completed tasks and work over a selected date range. Choose a recent period or a custom range to compare daily activity.',
            ),
            SizedBox(
              width: 170,
              child: AnchoredSelectField<_Period>(
                key: ValueKey(period),
                initialValue: period,
                onChanged: (value) {
                  if (value != null) _setPeriod(value);
                },
                items: const [
                  DropdownMenuItem(
                    value: _Period.week,
                    child: Text('Last 7 days'),
                  ),
                  DropdownMenuItem(
                    value: _Period.month,
                    child: Text('Last 30 days'),
                  ),
                  DropdownMenuItem(
                    value: _Period.quarter,
                    child: Text('Last 90 days'),
                  ),
                  DropdownMenuItem(
                    value: _Period.custom,
                    child: Text('Custom range'),
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          '$from to $through · Local calendar days',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metric(
              'Completed tasks',
              '${report.completed}',
              'Actual completion date',
              Icons.task_alt_outlined,
            ),
            _metric(
              'Created tasks',
              '${report.created}',
              'Creation date',
              Icons.add_task_outlined,
            ),
            _metric(
              'Planned tasks',
              '${report.planned}',
              'Planned date, independent of completion',
              Icons.event_outlined,
            ),
            _metric(
              'Actual work',
              _duration(report.work),
              'Overlaps counted once',
              Icons.timer_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Daily activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Completed tasks and confirmed work time. Archived tasks remain in history; Trash is excluded.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: math.min(430.0, report.days.length * 54.0),
          child: ListView.builder(
            itemCount: report.days.length,
            itemBuilder: (context, index) {
              final day = report.days[report.days.length - index - 1];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 96, child: Text(day.date)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: day.completed / maxCompleted,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 118,
                      child: Text(
                        '${day.completed} done · ${_duration(day.work)}',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text('Habits in range', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          report.habitDue == 0
              ? 'No scheduled habit days in this range.'
              : '${report.habitSuccess} successful of ${report.habitDue} due days '
                    '(${(report.habitSuccess / report.habitDue * 100).round()}%). '
                    '${report.habitRecorded} days recorded.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text(
          'Completions by project',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (report.projects.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No completed tasks in this range.'),
          ),
        for (final project in report.projects)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              project.projectId == null
                  ? 'No project'
                  : projectNames[project.projectId] ?? 'Former project',
            ),
            trailing: Text('${project.completed}'),
          ),
        const SizedBox(height: 14),
        Text('Goals now', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          '${report.currentCompletedGoals} completed of ${report.currentGoals} active goals. '
          'This is the current state, independent of the report range.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
