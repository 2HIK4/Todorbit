// Disposable-emulator acceptance entry point only. Production uses lib/main.dart.
// This replaces discovery/transport with a local fixture, retaining the actual
// update screen, native verification, permission and system installer path.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/software_update_service.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/settings/android_software_updates_page.dart';
import 'package:life_manager/main.dart' as app;
import 'package:life_manager/platform/android/android_platform.dart';
import 'package:life_manager/platform/android/android_update_service.dart';
import 'package:path/path.dart' as path;

@pragma('vm:entry-point')
Future<void> androidBackgroundMain() => app.androidBackgroundMain();

NavigatorState navigator() {
  NavigatorState? found;
  void visit(Element element) {
    if (element is StatefulElement && element.state is NavigatorState) {
      found ??= element.state as NavigatorState;
    }
    element.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  return found!;
}

class FixtureUpdates extends AndroidUpdateService {
  FixtureUpdates(this.source, this.release);
  final File source;
  final AndroidUpdateRelease release;
  @override
  Future<AndroidUpdateRelease?> check(
    AndroidUpdateDevice device,
    UpdateChannel channel,
  ) async => release;
  @override
  Future<File> download(
    AndroidUpdateRelease release,
    AndroidUpdateDevice device,
    void Function(int, int) progress,
  ) async {
    final file = await source.copy(
      path.join(device.directory!, 'acceptance.apk'),
    );
    progress(release.size, release.size);
    return file;
  }
}

Future<void> main(List<String> args) async {
  if (!kDebugMode || !Platform.isAndroid) {
    throw StateError('Disposable Android debug acceptance only.');
  }
  enableFlutterDriverExtension(
    handler: (message) async {
      final nav = navigator();
      final controller = ProviderScope.containerOf(
        nav.context,
        listen: false,
      ).read(appControllerProvider);
      String? snapshotPath;
      if (message == 'seed') {
        final category =
            (await controller.repository.categories())
                .where((value) => value.name == 'Update acceptance')
                .firstOrNull ??
            await controller.repository.addCategory('Update acceptance');
        final project =
            (await controller.repository.projects())
                .where(
                  (value) =>
                      value.categoryId == category.id &&
                      value.name == 'Update project',
                )
                .firstOrNull ??
            await controller.repository.addProject(
              category.id,
              'Update project',
            );
        if (!(await controller.repository.tasks()).any(
          (value) =>
              value.projectId == project.id &&
              value.title == 'Preserve through Android update',
        )) {
          await controller.addTask(
            TaskDraft(
              title: 'Preserve through Android update',
              categoryId: category.id,
              projectId: project.id,
            ),
          );
        }
        final now = DateTime.now();
        if (!(await controller.repository.events()).any(
          (value) => value.title == 'Preserve update event',
        )) {
          await controller.addEvent(
            EventDraft(
              title: 'Preserve update event',
              startsAt: now,
              endsAt: now.add(const Duration(hours: 1)),
            ),
          );
        }
        await controller.setTheme(ThemeModePreference.dark);
        snapshotPath = (await controller.backupService!.createBackup(
          BackupKind.manual,
        )).file.path;
      }
      if (message == 'fixture-update') {
        final root = (await AndroidPlatform.channel.invokeMethod<String>(
          'dataRoot',
        ))!;
        final directory = path.join(root, 'update-fixtures');
        final metadata = jsonDecode(
          await File(path.join(directory, 'candidate.json')).readAsString(),
        ) as Map<String, dynamic>;
        final release = AndroidUpdateRelease(
          tag: 'v${metadata['versionName']}',
          versionName: metadata['versionName'] as String,
          versionCode: metadata['versionCode'] as int,
          publishedAt: DateTime.now().toUtc(),
          notes: '## Isolated emulator fixture\nVerify update approval and data preservation.',
          uri: Uri.parse(
            'https://github.com/2HIK4/Todorbit/releases/download/v${metadata['versionName']}/Todorbit-${metadata['versionName']}-android-universal.apk',
          ),
          size: metadata['size'] as int,
          sha256Digest: metadata['sha256'] as String,
        );
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => AndroidSoftwareUpdatesPage(
              service: FixtureUpdates(
                File(path.join(directory, 'candidate.apk')),
                release,
              ),
            ),
          ),
        );
      }
      final info = await AndroidUpdateDevice.load();
      return jsonEncode({
        'snapshot': ?snapshotPath,
        'versionCode': info.versionCode,
        'theme': controller.theme.name,
        'tasks': [
          for (final task in await controller.repository.tasks())
            {'id': task.id, 'title': task.title},
        ],
        'events': [
          for (final event in await controller.repository.events())
            {'id': event.id, 'title': event.title},
        ],
      });
    },
  );
  await app.main(args);
}
