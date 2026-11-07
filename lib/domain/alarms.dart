import 'dart:convert';

/// Portable user intent. Delivery handles, snoozes and receipts are device-local.
class AlarmConfig {
  const AlarmConfig({
    this.mode = 'off',
    this.at,
    this.localMinute = 540,
    this.minutesBefore = 0,
    this.sound = 'alarm',
    this.vibrate = true,
    this.durationSeconds = 30,
  });

  /// custom = UTC instant; relative = event/session start; planned = local task day.
  final String mode;
  final DateTime? at;
  final int localMinute;
  final int minutesBefore;
  final String sound;
  final bool vibrate;
  final int durationSeconds;
  bool get enabled => mode != 'off';

  Map<String, Object?> toJson() => {
    'version': 1,
    'mode': mode,
    'at': at?.toUtc().toIso8601String(),
    'localMinute': localMinute,
    'minutesBefore': minutesBefore,
    'sound': sound,
    'vibrate': vibrate,
    'durationSeconds': durationSeconds,
  };

  factory AlarmConfig.fromJson(Map<String, dynamic> value) {
    final mode = value['mode'];
    final rawAt = value['at'];
    final at = rawAt is String ? DateTime.tryParse(rawAt)?.toUtc() : null;
    if (value.length != 8 ||
        value.keys.any(
          (k) => !{
            'version',
            'mode',
            'at',
            'localMinute',
            'minutesBefore',
            'sound',
            'vibrate',
            'durationSeconds',
          }.contains(k),
        ) ||
        (rawAt != null &&
            (rawAt is! String ||
                at == null ||
                !rawAt.endsWith('Z') ||
                !rawAt.startsWith(at.toIso8601String().substring(0, 19)))) ||
        value['version'] != 1 ||
        !{'off', 'custom', 'relative', 'planned'}.contains(mode) ||
        (mode == 'custom' && at == null) ||
        value['localMinute'] is! int ||
        (value['localMinute'] as int) < 0 ||
        (value['localMinute'] as int) > 1439 ||
        value['minutesBefore'] is! int ||
        (value['minutesBefore'] as int) < 0 ||
        (value['minutesBefore'] as int) > 10080 ||
        !{'alarm', 'notification', 'ringtone'}.contains(value['sound']) ||
        value['vibrate'] is! bool ||
        value['durationSeconds'] is! int ||
        !{15, 30, 60, 120}.contains(value['durationSeconds'])) {
      throw const FormatException('Invalid alarm settings');
    }
    return AlarmConfig(
      mode: mode as String,
      at: at,
      localMinute: value['localMinute'] as int,
      minutesBefore: value['minutesBefore'] as int,
      sound: value['sound'] as String,
      vibrate: value['vibrate'] as bool,
      durationSeconds: value['durationSeconds'] as int,
    );
  }

  AlarmConfig copyWith({
    String? mode,
    DateTime? at,
    int? localMinute,
    int? minutesBefore,
    String? sound,
    bool? vibrate,
    int? durationSeconds,
  }) => AlarmConfig(
    mode: mode ?? this.mode,
    at: at ?? this.at,
    localMinute: localMinute ?? this.localMinute,
    minutesBefore: minutesBefore ?? this.minutesBefore,
    sound: sound ?? this.sound,
    vibrate: vibrate ?? this.vibrate,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );

  bool sameAs(AlarmConfig other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  DateTime? trigger({String? plannedDay, DateTime? start}) {
    if (!enabled) return null;
    if (mode == 'custom') return at;
    if (mode == 'planned') {
      if (plannedDay == null) return null;
      final day = DateTime.tryParse(plannedDay);
      if (day == null) return null;
      return DateTime(
        day.year,
        day.month,
        day.day,
        localMinute ~/ 60,
        localMinute % 60,
      ).subtract(Duration(minutes: minutesBefore)).toUtc();
    }
    return start?.subtract(Duration(minutes: minutesBefore)).toUtc();
  }
}

class AlarmRule {
  const AlarmRule({
    required this.id,
    required this.config,
    required this.updatedAt,
    this.taskId,
    this.eventId,
    this.seriesId,
    this.nominalDate = '',
  });
  final String id;
  final AlarmConfig config;
  final String updatedAt;
  final String? taskId;
  final String? eventId;
  final String? seriesId;
  final String nominalDate;
}
