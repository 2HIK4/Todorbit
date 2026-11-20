import 'package:flutter/material.dart';

/// Semantic design tokens for Todorbit UI components, extending ThemeData.
@immutable
class TodorbitThemeTokens extends ThemeExtension<TodorbitThemeTokens> {
  const TodorbitThemeTokens({
    required this.priorityNone,
    required this.priorityLow,
    required this.priorityMedium,
    required this.priorityHigh,
    required this.statusNotStarted,
    required this.statusInProgress,
    required this.statusWaiting,
    required this.statusOnHold,
    required this.statusCompleted,
    required this.statusCancelled,
  });

  final Color priorityNone;
  final Color priorityLow;
  final Color priorityMedium;
  final Color priorityHigh;

  final Color statusNotStarted;
  final Color statusInProgress;
  final Color statusWaiting;
  final Color statusOnHold;
  final Color statusCompleted;
  final Color statusCancelled;

  factory TodorbitThemeTokens.light() => const TodorbitThemeTokens(
    priorityNone: Color(0xFF757575),
    priorityLow: Color(0xFF2E7D32),
    priorityMedium: Color(0xFFF57C00),
    priorityHigh: Color(0xFFD32F2F),
    statusNotStarted: Color(0xFF757575),
    statusInProgress: Color(0xFF1976D2),
    statusWaiting: Color(0xFF8E24AA),
    statusOnHold: Color(0xFFF57C00),
    statusCompleted: Color(0xFF388E3C),
    statusCancelled: Color(0xFF9E9E9E),
  );

  factory TodorbitThemeTokens.dark() => const TodorbitThemeTokens(
    priorityNone: Color(0xFF9E9E9E),
    priorityLow: Color(0xFF81C784),
    priorityMedium: Color(0xFFFFB74D),
    priorityHigh: Color(0xFFE57373),
    statusNotStarted: Color(0xFF9E9E9E),
    statusInProgress: Color(0xFF64B5F6),
    statusWaiting: Color(0xFFBA68C8),
    statusOnHold: Color(0xFFFFB74D),
    statusCompleted: Color(0xFF81C784),
    statusCancelled: Color(0xFF757575),
  );

  @override
  TodorbitThemeTokens copyWith({
    Color? priorityNone,
    Color? priorityLow,
    Color? priorityMedium,
    Color? priorityHigh,
    Color? statusNotStarted,
    Color? statusInProgress,
    Color? statusWaiting,
    Color? statusOnHold,
    Color? statusCompleted,
    Color? statusCancelled,
  }) {
    return TodorbitThemeTokens(
      priorityNone: priorityNone ?? this.priorityNone,
      priorityLow: priorityLow ?? this.priorityLow,
      priorityMedium: priorityMedium ?? this.priorityMedium,
      priorityHigh: priorityHigh ?? this.priorityHigh,
      statusNotStarted: statusNotStarted ?? this.statusNotStarted,
      statusInProgress: statusInProgress ?? this.statusInProgress,
      statusWaiting: statusWaiting ?? this.statusWaiting,
      statusOnHold: statusOnHold ?? this.statusOnHold,
      statusCompleted: statusCompleted ?? this.statusCompleted,
      statusCancelled: statusCancelled ?? this.statusCancelled,
    );
  }

  /// Returns the semantic color corresponding to the numeric priority level (0-3).
  Color colorForPriority(int priority) {
    switch (priority) {
      case 3:
        return priorityHigh;
      case 2:
        return priorityMedium;
      case 1:
        return priorityLow;
      default:
        return priorityNone;
    }
  }

  @override
  TodorbitThemeTokens lerp(ThemeExtension<TodorbitThemeTokens>? other, double t) {
    if (other is! TodorbitThemeTokens) return this;
    return TodorbitThemeTokens(
      priorityNone: Color.lerp(priorityNone, other.priorityNone, t)!,
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      statusNotStarted: Color.lerp(statusNotStarted, other.statusNotStarted, t)!,
      statusInProgress: Color.lerp(statusInProgress, other.statusInProgress, t)!,
      statusWaiting: Color.lerp(statusWaiting, other.statusWaiting, t)!,
      statusOnHold: Color.lerp(statusOnHold, other.statusOnHold, t)!,
      statusCompleted: Color.lerp(statusCompleted, other.statusCompleted, t)!,
      statusCancelled: Color.lerp(statusCancelled, other.statusCancelled, t)!,
    );
  }
}
