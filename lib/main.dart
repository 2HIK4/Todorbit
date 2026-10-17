import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_controller.dart';
import 'data/app_database.dart';
import 'data/life_repository.dart';
import 'features/workspace/workspace.dart';
import 'features/widget/desktop_widget.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final databaseFile = await AppDatabase.defaultFile();
  final database = await AppDatabase.openDefault();
  final controller = AppController(LifeRepository(database));
  await controller.refresh();
  final widgetMode = Platform.isWindows && args.contains('--widget');
  runApp(
    ProviderScope(
      overrides: [appControllerProvider.overrideWith((ref) => controller)],
      child: widgetMode
          ? DesktopWidgetApp(
              diagnostics: args.contains('--widget-diagnostics'),
              onExit: () async {
                await database.close();
                exit(0);
              },
            )
          : LifeManagerApp(databaseFile: databaseFile),
    ),
  );
}

class LifeManagerApp extends ConsumerStatefulWidget {
  const LifeManagerApp({super.key, this.databaseFile});

  final File? databaseFile;

  @override
  ConsumerState<LifeManagerApp> createState() => _LifeManagerAppState();
}

class _LifeManagerAppState extends ConsumerState<LifeManagerApp>
    with WidgetsBindingObserver {
  StreamSubscription<FileSystemEvent>? _databaseChanges;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final file = widget.databaseFile;
    if (Platform.isWindows && file != null) {
      _databaseChanges = file.parent.watch().listen((event) {
        if (!event.path.toLowerCase().startsWith(file.path.toLowerCase())) {
          return;
        }
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
          if (mounted) ref.read(appControllerProvider).refresh();
        });
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appControllerProvider).refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    _databaseChanges?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(appControllerProvider).theme;
    final mode = switch (preference) {
      ThemeModePreference.light => ThemeMode.light,
      ThemeModePreference.dark => ThemeMode.dark,
      ThemeModePreference.system => ThemeMode.system,
    };
    return MaterialApp(
      title: 'Life Manager',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const Workspace(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5365B5),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
