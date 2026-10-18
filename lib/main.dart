import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_controller.dart';
import 'data/app_database.dart';
import 'data/appearance_preference_store.dart';
import 'data/backup_service.dart';
import 'data/life_repository.dart';
import 'domain/appearance.dart';
import 'features/workspace/workspace.dart';
import 'features/widget/desktop_widget.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final databaseFile = await AppDatabase.defaultFile();
  final backupService = BackupService(databaseFile);
  try {
    await backupService.ensureAutomaticBackup(
      appSchemaVersion: AppDatabase.currentSchemaVersion,
    );
  } catch (failure) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Life Manager could not verify and back up its database. '
                'The database was not opened or migrated. Check disk space and file access, '
                'then restart the app.\n\n$failure',
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  final database = await AppDatabase.openDefault();
  final appearanceStore = await AppearancePreferenceStore.openDefault();
  final controller = AppController(
    LifeRepository(database),
    appearanceStore: appearanceStore,
    backupService: backupService,
  );
  await controller.initialize();
  final taskArgument = args.indexOf('--task-id');
  if (taskArgument >= 0 && taskArgument + 1 < args.length) {
    controller.select(args[taskArgument + 1]);
  }
  final legacyWidgetMode =
      Platform.isWindows && args.contains('--legacy-flutter-widget');
  runApp(
    ProviderScope(
      overrides: [appControllerProvider.overrideWith((ref) => controller)],
      child: legacyWidgetMode
          ? DesktopWidgetApp(
              diagnostics: args.contains('--widget-diagnostics'),
              onExit: () async {
                await database.close();
                exit(0);
              },
            )
          : LifeManagerApp(
              databaseFile: databaseFile,
              appearanceFile: appearanceStore.file,
            ),
    ),
  );
}

class LifeManagerApp extends ConsumerStatefulWidget {
  const LifeManagerApp({super.key, this.databaseFile, this.appearanceFile});

  final File? databaseFile;
  final File? appearanceFile;

  @override
  ConsumerState<LifeManagerApp> createState() => _LifeManagerAppState();
}

class _LifeManagerAppState extends ConsumerState<LifeManagerApp>
    with WidgetsBindingObserver {
  StreamSubscription<FileSystemEvent>? _databaseChanges;
  Timer? _refreshDebounce;
  Timer? _backupTimer;
  bool _databaseRefreshPending = false;
  bool _appearanceRefreshPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(appControllerProvider).backupService != null) {
      _backupTimer = Timer.periodic(const Duration(hours: 6), (_) {
        ref.read(appControllerProvider).checkAutomaticBackup();
      });
    }
    final file = widget.databaseFile;
    if (Platform.isWindows && file != null) {
      _databaseChanges = file.parent.watch().listen((event) {
        final changed = event.path.toLowerCase();
        final databaseChanged = changed.startsWith(file.path.toLowerCase());
        final appearanceChanged =
            widget.appearanceFile != null &&
            changed == widget.appearanceFile!.path.toLowerCase();
        if (!databaseChanged && !appearanceChanged) return;
        _databaseRefreshPending |= databaseChanged;
        _appearanceRefreshPending |= appearanceChanged;
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          final controller = ref.read(appControllerProvider);
          final refreshDatabase = _databaseRefreshPending;
          final refreshAppearance = _appearanceRefreshPending;
          _databaseRefreshPending = false;
          _appearanceRefreshPending = false;
          if (refreshDatabase) controller.refresh();
          if (refreshAppearance) controller.reloadTheme();
        });
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appControllerProvider).refresh();
      ref.read(appControllerProvider).checkAutomaticBackup();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    _backupTimer?.cancel();
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
