import '../data/app_database.dart';
import '../data/appearance_preference_store.dart';
import '../data/backup_service.dart';
import '../data/calendar_preference_store.dart';
import '../data/cloud/sync_engine.dart';
import '../data/life_repository.dart';
import '../data/migration_gate.dart';
import '../data/privacy_store.dart';
import '../data/profile_paths.dart';
import 'app_controller.dart';
import 'privacy_manager.dart';
import 'sync_controller.dart';
import 'sync_runtime.dart';

Future<bool> runBackgroundSync({
  Future<void> Function(LifeRepository, PrivacySettings)? publish,
}) async {
  AppDatabase? database;
  AppController? controller;
  PrivacyManager? privacy;
  SyncController? sync;
  try {
    final file = AppDatabase.fileInDataRoot(ProfilePaths.dataRoot());
    if (!await file.exists() || await MigrationGate.olderSchema(file) != null) {
      return false;
    }
    final recovery = BackupService(file);
    if (await recovery.hasScheduledRestore() ||
        await recovery.restoreAwaitingOpen()) {
      return false;
    }
    final privacyStore = await PrivacyStore.openDefault();
    final settings = await privacyStore.load();
    // Background work cannot manufacture an unlocked session. A protected
    // profile resumes through the foreground application's verified session.
    if (settings.enabled) return false;
    database = await AppDatabase.openDefault();
    final repository = LifeRepository(database);
    final state = await repository.syncExchangeStatus();
    if (state.binding == null ||
        !state.enabled ||
        !state.automatic ||
        state.quarantined) {
      return false;
    }
    controller = AppController(
      repository,
      backupService: recovery,
      appearanceStore: await AppearancePreferenceStore.openDefault(),
      calendarPreferenceStore: await CalendarPreferenceStore.openDefault(),
    );
    privacy = PrivacyManager(await PrivacyStore.openDefault(), settings);
    sync = createSyncRuntime(
      controller,
      privacy,
      timeBudget: const Duration(seconds: 30),
      refreshController: false,
      canExchange: () async =>
          !(await privacyStore.load()).enabled &&
          !await recovery.restoreAwaitingOpen(),
    );
    await sync.auth.load();
    await sync.engine.syncNow();
    final currentPrivacy = await privacyStore.load();
    if (!currentPrivacy.enabled &&
        !await recovery.hasScheduledRestore() &&
        !await recovery.restoreAwaitingOpen()) {
      await publish?.call(repository, currentPrivacy);
    }
    return sync.status.phase == SyncPhase.pending ||
        sync.status.phase == SyncPhase.offline;
  } finally {
    await sync?.shutdown();
    controller?.dispose();
    privacy?.dispose();
    await database?.close();
  }
}
