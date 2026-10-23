import 'package:flutter/material.dart';

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

List<int> weekdaysFrom(int firstWeekday) =>
    List.generate(7, (index) => (firstWeekday - 1 + index) % 7 + 1);

class WeekdayPickerRow extends StatelessWidget {
  const WeekdayPickerRow({
    super.key,
    required this.firstWeekday,
    required this.selected,
    required this.onSelected,
  });

  final int firstWeekday;
  final Set<int> selected;
  final void Function(int day, bool value)? onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Row(
      children: [
        for (final day in weekdaysFrom(firstWeekday))
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: weekdayNames[day - 1],
                child: Semantics(
                  label: weekdayNames[day - 1],
                  selected: selected.contains(day),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(7),
                    onTap: onSelected == null
                        ? null
                        : () => onSelected!(day, !selected.contains(day)),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        color: selected.contains(day)
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainer,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          bounds.maxWidth < 360
                              ? weekdayNames[day - 1].substring(0, 1)
                              : weekdayNames[day - 1],
                          style: TextStyle(
                            color: selected.contains(day)
                                ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
