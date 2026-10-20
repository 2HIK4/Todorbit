import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SpellingReviewButton extends StatelessWidget {
  const SpellingReviewButton({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;
  static const _channel = MethodChannel('life_manager/spell_check');

  Future<void> _review(BuildContext context) async {
    final original = controller.text;
    if (original.trim().isEmpty) return;
    try {
      final response = await _channel.invokeListMethod<dynamic>(
        'check',
        original,
      );
      if (!context.mounted) return;
      final entries = <_SpellingIssue>[];
      for (final value in response ?? const []) {
        if (value is! Map) continue;
        final start = value['start'];
        final length = value['length'];
        final word = value['word'];
        final suggestions = value['suggestions'];
        if (start is! int ||
            length is! int ||
            word is! String ||
            suggestions is! List ||
            start < 0 ||
            length < 1 ||
            start + length > original.length ||
            original.substring(start, start + length) != word) {
          continue;
        }
        entries.add(
          _SpellingIssue(
            start,
            length,
            word,
            suggestions.whereType<String>().toSet().toList(),
          ),
        );
      }
      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No likely misspellings found.')),
        );
        return;
      }
      final choices = <int, String>{};
      final apply = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: const Text('Review spelling'),
            content: SizedBox(
              width: 480,
              height: 360,
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final issue = entries[index];
                  return ListTile(
                    title: Text(issue.word),
                    subtitle: DropdownButtonFormField<String?>(
                      initialValue: choices[index],
                      decoration: const InputDecoration(
                        labelText: 'Replacement',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Keep as written'),
                        ),
                        for (final suggestion in issue.suggestions)
                          DropdownMenuItem<String?>(
                            value: suggestion,
                            child: Text(suggestion),
                          ),
                      ],
                      onChanged: (value) => update(() {
                        if (value == null) {
                          choices.remove(index);
                        } else {
                          choices[index] = value;
                        }
                      }),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Apply selected'),
              ),
            ],
          ),
        ),
      );
      if (apply != true || controller.text != original) return;
      var updated = original;
      final ordered = choices.keys.toList()
        ..sort((a, b) => entries[b].start.compareTo(entries[a].start));
      for (final index in ordered) {
        final issue = entries[index];
        updated = updated.replaceRange(
          issue.start,
          issue.start + issue.length,
          choices[index]!,
        );
      }
      controller.text = updated;
    } on PlatformException catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Spelling review is unavailable.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: enabled && Platform.isWindows
        ? 'Review spelling'
        : 'Spelling review unavailable',
    onPressed: enabled && Platform.isWindows ? () => _review(context) : null,
    icon: const Icon(Icons.spellcheck),
  );
}

class _SpellingIssue {
  const _SpellingIssue(this.start, this.length, this.word, this.suggestions);
  final int start;
  final int length;
  final String word;
  final List<String> suggestions;
}
