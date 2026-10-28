import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'features/shared/week_start_localizations.dart';
import 'features/shared/desktop_tooltip_theme.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_controller.dart';
import 'app/privacy_manager.dart';
import 'data/app_database.dart';
import 'data/widget_configuration_store.dart';
import 'data/appearance_preference_store.dart';
import 'data/calendar_preference_store.dart';
import 'data/backup_service.dart';
import 'data/life_repository.dart';
import 'data/migration_gate.dart';
import 'data/privacy_store.dart';
import 'data/profile_paths.dart';
import 'data/software_update_service.dart';
import 'domain/appearance.dart';
import 'features/workspace/workspace.dart';
import 'features/settings/privacy_dialog.dart';
import 'features/settings/settings_transfer.dart';
import 'features/widget/desktop_widget.dart';
import 'features/widget/native_widget_service.dart';
import 'domain/widget_configuration.dart';

Future<void> main(List<String> args) => _startApplication(args);

Future<void> _startApplication(
  List<String> args, {
  bool migrationApproved = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final privacyStore = await PrivacyStore.openDefault();
  late final PrivacySettings privacySettings;
  try {
    privacySettings = await privacyStore.load();
    if (privacySettings.enabled && privacySettings.lockOnLaunch) {
      await privacyStore.setSession(unlocked: false);
    }
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Privacy settings could not be read. Restore the settings from a trusted backup before opening Todorbit.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  final root = ProfilePaths.dataRoot();
  final freshDatabase = AppDatabase.fileInDataRoot(root);
  final legacyDatabase = ProfilePaths.legacyDatabaseIn(root);
  final offerLegacyImport =
      !ProfilePaths.usesLegacyProfileIn(root) &&
      !await freshDatabase.exists() &&
      await legacyDatabase.exists();
  final databaseFile = await AppDatabase.defaultFile();
  final backupService = BackupService(databaseFile);
  late final AppDatabase database;
  try {
    if (await backupService.pendingRestoreName() != null) {
      final companion = NativeWidgetService();
      if (companion.isAvailable) {
        await companion.close();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      await backupService.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
    }
    final olderSchema = await MigrationGate.olderSchema(databaseFile);
    if (olderSchema != null && olderSchema > 0 && !migrationApproved) {
      runApp(_MigrationApprovalApp(arguments: args, olderSchema: olderSchema));
      return;
    }
    // A schema-0 file is not a valid managed backup. Its creation transaction
    // must validate/recover it first, without deleting or replacing the file.
    if (olderSchema != 0) {
      await backupService.ensureAutomaticBackup(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
    }
    database = await AppDatabase.openDefault();
  } catch (failure) {
    runApp(
      _StartupFailureApp(
        backupService: backupService,
        hasPendingRestore: await backupService.hasScheduledRestore(),
        arguments: args,
        failure: '$failure',
      ),
    );
    return;
  }
  final privacy = PrivacyManager(privacyStore, privacySettings);
  privacy.startInactivityCheck();
  final appearanceStore = await AppearancePreferenceStore.openDefault();
  final calendarPreferenceStore = await CalendarPreferenceStore.openDefault();
  final controller = AppController(
    LifeRepository(database),
    appearanceStore: appearanceStore,
    calendarPreferenceStore: calendarPreferenceStore,
    backupService: backupService,
    widgetStore: WidgetConfigurationStore(databaseFile.parent),
  );
  var controllerInitialized = false;
  try {
    await controller.initialize();
    controllerInitialized = true;
    final restoredSettings = await backupService.restoredPortableSettings();
    if (restoredSettings != null) {
      final transfer = SettingsTransfer.decode(restoredSettings);
      await transfer.applyTo(controller, transfer.categories.keys.toSet());
      // Do not open the app with a replayable personalization receipt. If
      // finalization fails, startup stops before the user can make new edits.
      await backupService.markRestoreOpened();
    }
  } catch (failure) {
    controller.dispose();
    await database.close();
    privacy.dispose();
    runApp(
      _StartupFailureApp(
        backupService: backupService,
        hasPendingRestore: await backupService.hasScheduledRestore(),
        arguments: args,
        failure: controllerInitialized
            ? 'Database opened, but restored personalization could not be finalized: $failure'
            : 'Database or profile settings could not be loaded: $failure',
        databaseOpened: controllerInitialized,
      ),
    );
    return;
  }
  try {
    await backupService.markRestoreOpened();
  } catch (_) {
    // A status receipt must never block access to a verified database.
  }
  if (Platform.isWindows) unawaited(_checkUpdatesInBackground());
  if (Platform.isWindows) {
    final companion = NativeWidgetService();
    if (companion.isAvailable && kReleaseMode) {
      try {
        await companion.synchronizeStartup();
      } catch (failure) {
        debugPrint('Could not synchronize widget startup: $failure');
      }
    }
    if (companion.isAvailable &&
        ((await controller.repository.notificationSettings()).enabled ||
            await controller.repository.hasEventReminders() ||
            await controller.repository.hasTaskReminders())) {
      try {
        await companion.ensureRemindersRunning();
      } catch (failure) {
        debugPrint('Could not start reminder companion: $failure');
      }
    }
  }
  final taskArgument = args.indexOf('--task-id');
  if (taskArgument >= 0 && taskArgument + 1 < args.length) {
    controller.select(args[taskArgument + 1]);
  }
  final legacyWidgetMode =
      Platform.isWindows && args.contains('--legacy-flutter-widget');
  runApp(
    ProviderScope(
      overrides: [
        appControllerProvider.overrideWith((ref) => controller),
        privacyManagerProvider.overrideWith((ref) => privacy),
      ],
      child: legacyWidgetMode && !privacy.enabled
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
              openAppearance: args.contains('--appearance'),
              initialNavigation:
                  args.contains('--navigate') &&
                      args.indexOf('--navigate') + 1 < args.length
                  ? args[args.indexOf('--navigate') + 1]
                  : null,
              editWidget: args.contains('--edit-widget')
                  ? (args.contains('calendar')
                        ? DesktopWidgetKind.calendar
                        : DesktopWidgetKind.tasks)
                  : null,
              legacyImportFile: offerLegacyImport ? legacyDatabase : null,
            ),
    ),
  );
}

Future<void> _checkUpdatesInBackground() async {
  final service = SoftwareUpdateService();
  try {
    final store = UpdatePreferenceStore.forActiveProfile();
    final preferences = await store.load();
    if (!preferences.automaticChecks ||
        (preferences.lastChecked != null &&
            DateTime.now().toUtc().difference(preferences.lastChecked!) <
                const Duration(hours: 24))) {
      return;
    }
    final version = await const MethodChannel('life_manager/window_theme')
        .invokeMethod<String>('getVersion');
    if (version == null) return;
    await service.check(
      currentVersion: version,
      channel: preferences.channel,
      portable:
          ProfilePaths.portableDirectoryIn(
            ProfilePaths.dataRoot(),
            Platform.resolvedExecutable,
          ) !=
          null,
    );
    await store.save(preferences.copyWith(lastChecked: DateTime.now().toUtc()));
  } catch (error) {
    debugPrint('Background update check failed: $error');
  } finally {
    service.close();
  }
}

class _MigrationApprovalApp extends StatefulWidget {
  const _MigrationApprovalApp({
    required this.arguments,
    required this.olderSchema,
  });
  final List<String> arguments;
  final int olderSchema;

  @override
  State<_MigrationApprovalApp> createState() => _MigrationApprovalAppState();
}

class _MigrationApprovalAppState extends State<_MigrationApprovalApp> {
  bool busy = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 480,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_outlined, size: 40),
                const SizedBox(height: 16),
                const Text('Database upgrade required'),
                const SizedBox(height: 12),
                Text(
                  'This database uses schema ${widget.olderSchema}. Todorbit will create and verify a Before upgrade backup, then migrate it to schema ${AppDatabase.currentSchemaVersion}. If backup or migration fails, the workspace will not open. Your data will not be reset.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          await _startApplication(
                            widget.arguments,
                            migrationApproved: true,
                          );
                        },
                  child: const Text('Back up and upgrade database'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy ? null : () => exit(0),
                  child: const Text('Exit without changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StartupFailureApp extends StatefulWidget {
  const _StartupFailureApp({
    required this.backupService,
    required this.hasPendingRestore,
    required this.arguments,
    required this.failure,
    this.databaseOpened = false,
  });
  final BackupService backupService;
  final bool hasPendingRestore;
  final List<String> arguments;
  final String failure;
  final bool databaseOpened;

  @override
  State<_StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<_StartupFailureApp> {
  bool busy = false;
  String? error;

  Future<void> _cancelRestore() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.backupService.cancelScheduledRestore();
      await main(widget.arguments);
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = '$failure';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.databaseOpened
                    ? 'The database opened, but restored personalization could not be applied. The main app was not started. Your Before Restore database and settings recovery files remain available.'
                    : 'Todorbit could not prepare its database. The main app was not started. Review the error below before retrying.',
              ),
              const SizedBox(height: 12),
              SelectableText(widget.failure),
              const SizedBox(height: 12),
              const Text(
                'Check disk space and file access, then restart the app.',
              ),
              if (widget.hasPendingRestore)
                OutlinedButton(
                  onPressed: busy ? null : _cancelRestore,
                  child: const Text(
                    'Cancel scheduled restore and retry current database',
                  ),
                ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
    ),
  );
}

class LifeManagerApp extends ConsumerStatefulWidget {
  const LifeManagerApp({
    super.key,
    this.databaseFile,
    this.appearanceFile,
    this.openAppearance = false,
    this.editWidget,
    this.initialNavigation,
    this.legacyImportFile,
  });

  final File? databaseFile;
  final File? appearanceFile;
  final bool openAppearance;
  final DesktopWidgetKind? editWidget;
  final String? initialNavigation;
  final File? legacyImportFile;

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
  String? _lastCaptionTheme;

  void _syncCaptionTheme(ThemeData theme) {
    if (!Platform.isWindows) return;
    String rgb(Color color) => color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    final values = [
      theme.brightness == Brightness.dark ? 'dark' : 'light',
      rgb(theme.colorScheme.surface),
      rgb(theme.colorScheme.onSurface),
    ];
    final signature = values.join('/');
    if (_lastCaptionTheme == signature) return;
    _lastCaptionTheme = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await const MethodChannel('life_manager/window_theme')
            .invokeMethod<void>('set', values);
      } on MissingPluginException {
        _lastCaptionTheme = null;
      } on PlatformException {
        _lastCaptionTheme = null;
      }
    });
  }

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
    final privacy = ref.read(privacyManagerProvider);
    if (state == AppLifecycleState.resumed) {
      unawaited(privacy.resumed());
      ref.read(appControllerProvider).refresh();
      ref.read(appControllerProvider).checkAutomaticBackup();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      privacy.becameInactive();
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
    final privacy = ref.watch(privacyManagerProvider);
    final mode = switch (preference) {
      ThemeModePreference.light => ThemeMode.light,
      ThemeModePreference.dark => ThemeMode.dark,
      ThemeModePreference.system => ThemeMode.system,
    };
    return MaterialApp(
      localizationsDelegates: [
        WeekStartLocalizationsDelegate(
          ref.watch(appControllerProvider).firstWeekday,
        ),
      ],
      title: 'Todorbit',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _theme(
        Brightness.light,
        ref.watch(appControllerProvider).customization.light,
      ),
      darkTheme: _theme(
        Brightness.dark,
        ref.watch(appControllerProvider).customization.dark,
      ),
      builder: (context, child) {
        _syncCaptionTheme(Theme.of(context));
        final existing = MediaQuery.of(context);
        final systemScale = existing.textScaler.scale(16) / 16;
        final preferenceScale = ref
            .read(appControllerProvider)
            .customization
            .textScale;
        return MediaQuery(
          data: existing.copyWith(
            textScaler: TextScaler.linear(systemScale * preferenceScale),
            disableAnimations:
                ref.read(appControllerProvider).customization.reducedMotion ||
                existing.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: privacy.locked
          ? const LockScreen()
          : Listener(
              onPointerDown: (_) => privacy.activity(),
              child: Focus(
                onKeyEvent: (_, _) {
                  privacy.activity();
                  return KeyEventResult.ignored;
                },
                child: Workspace(
                  openAppearance: widget.openAppearance,
                  editWidget: widget.editWidget,
                  initialNavigation: widget.initialNavigation,
                  legacyImportFile: widget.legacyImportFile,
                ),
              ),
            ),
    );
  }

  ThemeData _theme(Brightness brightness, ThemePalette palette) {
    // Custom colors replace the seed's tonal backgrounds. Select the stronger
    // black/white contrast for their foregrounds as well (at least 4.5:1).
    Color foregroundOn(Color background) {
      final luminance = background.computeLuminance();
      return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05)
          ? Colors.black
          : Colors.white;
    }

    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette['accent'],
          brightness: brightness,
        ).copyWith(
          surface: palette['surface'],
          onSurface: palette['primaryText'],
          onSurfaceVariant: palette['secondaryText'],
          primary: palette['accent'],
          onPrimary: foregroundOn(palette['accent']),
          outline: palette['border'],
          outlineVariant: palette['border'],
          error: palette['error'],
          onError: foregroundOn(palette['error']),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme;
    return ThemeData(
      useMaterial3: true,
      visualDensity: ref.read(appControllerProvider).customization.compact
          ? VisualDensity.compact
          : VisualDensity.standard,
      colorScheme: scheme,
      tooltipTheme: desktopTooltipTheme(scheme),
      scaffoldBackgroundColor: palette['background'],
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodySmall: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        helperStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        childrenPadding: EdgeInsets.symmetric(vertical: 12),
        shape: Border(),
        collapsedShape: Border(),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
