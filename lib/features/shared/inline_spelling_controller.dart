import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef SpellingCheck = Future<List<dynamic>?> Function(String text);

/// Marks Windows spelling results in the editable text without changing input.
class InlineSpellingController extends TextEditingController {
  InlineSpellingController({
    super.text,
    this._enabled = true,
    SpellingCheck? check,
  }) : _nativeChecker = check == null,
       _check = check ?? _checkOnWindows {
    _schedule();
  }

  static const _channel = MethodChannel('life_manager/spell_check');
  final SpellingCheck _check;
  final bool _nativeChecker;
  Timer? _timer;
  bool _enabled;
  int _generation = 0;
  List<({int start, int end})> _issues = [];

  static Future<List<dynamic>?> _checkOnWindows(String text) =>
      _channel.invokeListMethod<dynamic>('check', text);

  bool get enabled => _enabled;
  set enabled(bool next) {
    if (_enabled == next) return;
    _enabled = next;
    _schedule();
  }

  @override
  set value(TextEditingValue next) {
    final changed = next.text != value.text;
    super.value = next;
    if (changed) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final generation = ++_generation;
    _issues = [];
    notifyListeners();
    final original = text;
    if (!_enabled ||
        original.trim().isEmpty ||
        original.length > 20000 ||
        (!Platform.isWindows && _nativeChecker)) {
      return;
    }
    _timer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final result = await _check(original);
        if (generation != _generation || text != original) return;
        final found = <({int start, int end})>[];
        for (final entry in result ?? const []) {
          if (entry is! Map) continue;
          final start = entry['start'];
          final length = entry['length'];
          final word = entry['word'];
          if (start is! int ||
              length is! int ||
              word is! String ||
              start < 0 ||
              length <= 0 ||
              start + length > original.length ||
              original.substring(start, start + length) != word) {
            continue;
          }
          found.add((start: start, end: start + length));
        }
        found.sort((a, b) => a.start.compareTo(b.start));
        _issues = found;
        notifyListeners();
      } on PlatformException {
        // Windows may not have the en-US dictionary installed.
      } on MissingPluginException {
        // Other platforms and widget tests have no native spelling channel.
      }
    });
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_issues.isEmpty ||
        (withComposing &&
            value.composing.isValid &&
            !value.composing.isCollapsed)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final children = <InlineSpan>[];
    var offset = 0;
    for (final issue in _issues) {
      if (issue.start < offset || issue.end > text.length) continue;
      if (issue.start > offset) {
        children.add(TextSpan(text: text.substring(offset, issue.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(issue.start, issue.end),
          style: const TextStyle(
            decoration: TextDecoration.underline,
            decorationColor: Colors.red,
            decorationStyle: TextDecorationStyle.wavy,
            decorationThickness: 1.5,
          ),
        ),
      );
      offset = issue.end;
    }
    if (offset < text.length) {
      children.add(TextSpan(text: text.substring(offset)));
    }
    return TextSpan(style: style, children: children);
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
