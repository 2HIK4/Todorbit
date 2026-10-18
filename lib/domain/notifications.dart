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
