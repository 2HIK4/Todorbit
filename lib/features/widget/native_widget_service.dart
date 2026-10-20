import 'dart:io';

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

  Future<void> hide() => _command('hide');
  Future<void> toggle() => _command('toggle');
  Future<void> quickAdd() => _command('quick-add');
  Future<void> close() => _command('exit');
  Future<void> setTheme(String theme) => _command('theme-$theme');
  Future<void> setView(String view) => _command('view-$view');

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
    if (arguments.isNotEmpty && arguments.first == '--widget-command') {
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
