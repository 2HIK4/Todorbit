import 'package:flutter/material.dart';

const builtInIcons = <String, IconData>{
  'task': Icons.task_alt_outlined,
  'school': Icons.school_outlined,
  'book': Icons.menu_book_outlined,
  'code': Icons.code,
  'work': Icons.work_outline,
  'home': Icons.home_outlined,
  'fitness': Icons.fitness_center,
  'music': Icons.music_note_outlined,
  'travel': Icons.flight_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'science': Icons.science_outlined,
  'calendar': Icons.calendar_month_outlined,
  'health': Icons.medical_services_outlined,
  'folder': Icons.folder_outlined,
  'star': Icons.star_outline,
  'energy': Icons.bolt_outlined,
  'coffee': Icons.coffee_outlined,
  'heart': Icons.favorite_outline,
  'pets': Icons.pets_outlined,
  'language': Icons.language_outlined,
  'group': Icons.groups_outlined,
  'database': Icons.storage_outlined,
  'draw': Icons.brush_outlined,
  'money': Icons.savings_outlined,
  'time': Icons.schedule_outlined,
  'camera': Icons.camera_alt_outlined,
  'food': Icons.restaurant_outlined,
  'garden': Icons.park_outlined,
  'idea': Icons.lightbulb_outline,
  'build': Icons.build_outlined,
};

IconData iconForKey(String? key, IconData fallback) =>
    builtInIcons[key] ?? fallback;

Future<(bool, String?)> chooseBuiltInIcon(
  BuildContext context, {
  required String? current,
}) async {
  String query = '';
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) {
        final matches = builtInIcons.entries
            .where((entry) => entry.key.contains(query.toLowerCase().trim()))
            .toList();
        return AlertDialog(
          title: const Text('Choose icon'),
          content: SizedBox(
            width: 360,
            height: 340,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search icons',
                  ),
                  onChanged: (value) => refresh(() => query = value),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final entry = matches[index];
                      final selected = current == entry.key;
                      return Tooltip(
                        message: entry.key,
                        child: Semantics(
                          selected: selected,
                          label: '${entry.key} icon',
                          child: IconButton(
                            tooltip: entry.key,
                            style: IconButton.styleFrom(
                              backgroundColor: selected
                                  ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                  : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh,
                              foregroundColor: selected
                                  ? Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () => Navigator.pop(context, entry.key),
                            icon: Icon(entry.value),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: current == null
                  ? null
                  : () => Navigator.pop(context, '__reset__'),
              child: const Text('Reset to default'),
            ),
          ],
        );
      },
    ),
  );
  if (result == null) return (false, current);
  return (true, result == '__reset__' ? null : result);
}
