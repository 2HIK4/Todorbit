import 'package:flutter/material.dart';

/// Formats a stored task day for display while preserving the calendar year.
String taskDateLabel(BuildContext context, String day) {
  final date = DateTime.tryParse(day);
  return date == null
      ? day
      : MaterialLocalizations.of(context).formatShortDate(date);
}
