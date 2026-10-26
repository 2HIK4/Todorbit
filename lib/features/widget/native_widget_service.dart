import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../data/app_database.dart';
import '../../data/profile_paths.dart';
import '../../domain/widget_configuration.dart';

class WidgetControlState {
  const WidgetControlState({
    this.layoutLocked = false,
    this.launchAtSignIn = true,
    this.backgroundOpacity = 100,
  });
  final bool layoutLocked;
  final bool launchAtSignIn;
  final int backgroundOpacity;
}

typedef WidgetProcessLauncher = Future<int> Function(
  String executable,
  List<String> arguments,
);

class NativeWidgetService {
  NativeWidgetService({
    WidgetProcessLauncher? launcher,
    this.widgetExecutable,
    this.appExecutable,
  }) : _launcher = launcher ?? _defaultLauncher,
       assert(widgetExecutable == null || widgetExecutable != '');

  final WidgetProcessLauncher _launcher;
  final String? widgetExecutable;
  final String? appExecutable;

  bool get isAvailable =>
      Platform.isWindows && File(executablePath).existsSync();

  String get executablePath =>
      widgetExecutable ??
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}TodorbitWidget.exe';

  String get appExecutablePath => appExecutable ?? Platform.resolvedExecutable;

  Future<void> show() => _run(['--widget', '--app-exe', appExecutablePath]);

  Future<void> ensureRemindersRunning() =>
      _run(['--widget', '--background', '--app-exe', appExecutablePath]);

  Future<void> reloadConfiguration() => _command('reload-configuration');

  /// Sends transient ordered state directly to the existing profile pipe.
  Future<bool> previewConfiguration({
    required DesktopWidgetKind kind,
    required String session,
    required int sequence,
    required WidgetConfiguration baseline,
    required WidgetConfiguration configuration,
    bool end = false,
  }) async {
    final directory = ProfilePaths.activeDirectory().path;
    final suffix = sha256
        .convert(utf8.encode(p.normalize(p.absolute(directory)).toLowerCase()))
        .toString()
        .substring(0, 16);
    return await const MethodChannel(
          'life_manager/widget_preview',
        ).invokeMethod<bool>('send', [
          suffix,
          'preview-configuration ${jsonEncode({'kind': kind.name, 'session': session, 'sequence': sequence, 'baseline': baseline.toJson(), 'configuration': configuration.toJson(), 'end': end})}',
        ]) ??
        false;
  }

  Future<void> setWidgetVisible(
    DesktopWidgetKind kind,
    bool visible,
  ) => _command(
    '${kind == DesktopWidgetKind.calendar ? 'calendar-' : ''}${visible ? 'show' : 'hide'}',
  );

  Future<void> hide() => _command('hide');
  Future<void> toggle() => _command('toggle');
  Future<void> quickAdd() => _command('quick-add');
  Future<void> close() => _command('exit');
  Future<void> setTheme(String theme) => _command('theme-$theme');
  Future<void> setView(String view) => _command('view-$view');
  Future<void> setLayoutLocked(bool locked) =>
      _command(locked ? 'layout-lock' : 'layout-unlock');
  Future<void> setLaunchAtSignIn(bool enabled) =>
      _command(enabled ? 'startup-on' : 'startup-off');
  Future<void> synchronizeStartup() async {
    final settings = await readSettings();
    await setLaunchAtSignIn(settings.launchAtSignIn);
  }

  Future<void> setOpacity(int value) {
    if (value < 0 || value > 100) throw RangeError.range(value, 0, 100);
    return _command('opacity-$value');
  }

  Future<WidgetControlState> readSettings() async {
    final database = await AppDatabase.defaultFile();
    final file = File(
      '${database.parent.path}${Platform.pathSeparator}widget-settings.json',
    );
    if (!await file.exists()) return const WidgetControlState();
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic>) return const WidgetControlState();
      final opacity = data['backgroundOpacity'];
      return WidgetControlState(
        layoutLocked: data['layoutLocked'] == true,
        launchAtSignIn: data['launchAtSignIn'] is bool
            ? data['launchAtSignIn'] as bool
            : true,
        backgroundOpacity: opacity is int && opacity >= 0 && opacity <= 100
            ? opacity
            : 100,
      );
    } on FormatException {
      return const WidgetControlState();
    }
  }

  Future<void> _command(String command) =>
      _run(['--widget-command', command, '--app-exe', appExecutablePath]);

  Future<void> _run(List<String> arguments) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('The native widget is available on Windows only.');
    }
    if (!File(executablePath).existsSync()) {
      throw StateError(
        'Native widget companion was not found beside Todorbit: $executablePath',
      );
    }
    final exitCode = await _launcher(executablePath, arguments);
    if (exitCode != 0) {
      throw ProcessException(executablePath, arguments, '', exitCode);
    }
  }

  static Future<int> _defaultLauncher(
    String executable,
    List<String> arguments,
  ) async {
    final command =
        arguments.length > 1 && arguments.first == '--widget-command'
        ? arguments[1]
        : null;
    // Show/reload/view commands can become the long-lived companion when no
    // instance exists. Waiting for their process would leave Settings busy until
    // the user exits both widgets. One-shot commands still report exit failures.
    final oneShot =
        const {
          'hide',
          'calendar-hide',
          'exit',
          'layout-lock',
          'layout-unlock',
          'startup-on',
          'startup-off',
          'theme-system',
          'theme-light',
          'theme-dark',
        }.contains(command) ||
        command?.startsWith('opacity-') == true;
    if (oneShot) {
      final result = await Process.run(executable, arguments);
      return result.exitCode;
    }
    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detached,
    );
    return process.pid > 0 ? 0 : 1;
  }
}
