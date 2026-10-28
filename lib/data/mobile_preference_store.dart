import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../app/app_controller.dart';
import 'profile_paths.dart';

class MobilePreferences {
  const MobilePreferences({
    this.destinations = const [
      WorkspaceView.today,
      WorkspaceView.all,
      WorkspaceView.calendar,
      WorkspaceView.upcoming,
    ],
    this.start = WorkspaceView.today,
    this.quietStart = 1320,
    this.quietEnd = 420,
    this.quietHours = false,
  });
  static const supported = [
    WorkspaceView.today,
    WorkspaceView.all,
    WorkspaceView.calendar,
    WorkspaceView.upcoming,
    WorkspaceView.inbox,
    WorkspaceView.anytime,
    WorkspaceView.habits,
    WorkspaceView.goals,
  ];
  final List<WorkspaceView> destinations;
  final WorkspaceView start;
  final int quietStart, quietEnd;
  final bool quietHours;

  MobilePreferences copyWith({
    List<WorkspaceView>? destinations,
    WorkspaceView? start,
    bool? quietHours,
    int? quietStart,
    int? quietEnd,
  }) => MobilePreferences(
    destinations: destinations ?? this.destinations,
    start: start ?? this.start,
    quietHours: quietHours ?? this.quietHours,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'destinations': destinations.map((v) => v.name).toList(),
    'start': start.name,
    'quietHours': quietHours,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
  };

  factory MobilePreferences.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported mobile preferences');
    }
    final names = json['destinations'];
    if (names is! List ||
        names.length < 3 ||
        names.length > 4 ||
        names.toSet().length != names.length ||
        names.any((v) => !supported.any((s) => s.name == v)) ||
        !supported.any((v) => v.name == json['start']) ||
        json['quietHours'] is! bool ||
        json['quietStart'] is! int ||
        json['quietEnd'] is! int ||
        (json['quietStart'] as int) < 0 ||
        (json['quietStart'] as int) > 1439 ||
        (json['quietEnd'] as int) < 0 ||
        (json['quietEnd'] as int) > 1439) {
      throw const FormatException('Invalid mobile preferences');
    }
    return MobilePreferences(
      destinations: names
          .map((n) => WorkspaceView.values.byName(n as String))
          .toList(),
      start: WorkspaceView.values.byName(json['start'] as String),
      quietHours: json['quietHours'] as bool,
      quietStart: json['quietStart'] as int,
      quietEnd: json['quietEnd'] as int,
    );
  }
}

class MobilePreferenceStore {
  MobilePreferenceStore(this.file);
  factory MobilePreferenceStore.forActiveProfile() => MobilePreferenceStore(
    File(
      path.join(ProfilePaths.activeDirectory().path, 'mobile-preferences.json'),
    ),
  );
  final File file;
  Future<MobilePreferences> load() async => await file.exists()
      ? MobilePreferences.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        )
      : const MobilePreferences();
  Future<void> save(MobilePreferences value) async {
    MobilePreferences.fromJson(value.toJson());
    // Never replace unreadable or future preferences with a default-based edit.
    if (await file.exists()) await load();
    await file.parent.create(recursive: true);
    final staging = File('${file.path}.tmp');
    await staging.writeAsString(jsonEncode(value.toJson()), flush: true);
    await staging.rename(file.path);
  }
}
