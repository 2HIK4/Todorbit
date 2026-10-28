class NotificationSettings {
  const NotificationSettings({
    this.dueReminders = false,
    this.dailySummary = false,
    this.localMinute = 540,
  });

  final bool dueReminders;
  final bool dailySummary;
  final int localMinute;

  bool get enabled => dueReminders || dailySummary;
}

/// Task planned days/deadlines have no clock time. Relative reminders target
/// an upcoming work session; custom reminders use an explicit UTC instant.
class TaskNotification {
  const TaskNotification({this.mode = 'off', this.at, this.minutesBefore = 0});
  final String mode;
  final DateTime? at;
  final int minutesBefore;
  bool get enabled => mode != 'off';
  bool sameAs(TaskNotification other) =>
      mode == other.mode &&
      at?.toUtc() == other.at?.toUtc() &&
      minutesBefore == other.minutesBefore;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'mode': mode,
    'at': at?.toUtc().toIso8601String(),
    'minutesBefore': minutesBefore,
  };
  factory TaskNotification.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        !['off', 'custom', 'session'].contains(json['mode'])) {
      throw const FormatException('Unsupported task notification');
    }
    final at = json['at'] == null
        ? null
        : DateTime.tryParse(json['at'] as String)?.toUtc();
    final minutes = json['minutesBefore'] ?? 0;
    if (minutes is! int ||
        minutes < 0 ||
        minutes > 10080 ||
        (json['mode'] == 'custom' && at == null)) {
      throw const FormatException('Invalid notification time');
    }
    return TaskNotification(
      mode: json['mode'] as String,
      at: at,
      minutesBefore: minutes,
    );
  }
}
