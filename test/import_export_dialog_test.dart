import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/features/settings/backup_dialog.dart';

class _TransferService extends BackupService {
  _TransferService() : super(File('unused-live.sqlite'));

  int importCalls = 0;
  int exportCalls = 0;
  int scheduleCalls = 0;
  final staged = BackupRecord(
    file: File('backups/manual-20261018T120000000000Z.sqlite'),
    kind: BackupKind.manual,
    createdAt: DateTime.utc(2026, 10, 18, 12),
    bytes: 4096,
    schemaVersion: AppDatabase.currentSchemaVersion,
  );

  @override
  Future<List<BackupRecord>> list() async => [staged];

  @override
  Future<String?> pendingRestoreName() async => null;

  @override
  Future<String?> restoreStatus() async => null;

  @override
  Future<BackupRecord> importSnapshot(
    File source, {
    required int appSchemaVersion,
  }) async {
    importCalls++;
    return staged;
  }

  @override
  Future<File> exportTo(File destination) async {
    exportCalls++;
    return destination;
  }

  @override
  Future<void> scheduleRestore(
    BackupRecord selected, {
    required int appSchemaVersion,
  }) async {
    scheduleCalls++;
  }

  @override
  Future<BackupSummary> summarize(BackupRecord selected) async =>
      const BackupSummary({'tasks': 2, 'events': 1});
}

void main() {
  testWidgets('cancelled pickers do not import, export, or queue restore', (
    tester,
  ) async {
    final service = _TransferService();
    await tester.binding.setSurfaceSize(const Size(900, 700));
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackupDialog(
              service: service,
              chooseImport: () async => null,
              chooseExport: () async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import SQLite'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export SQLite'));
      await tester.pumpAndSettle();
      expect(service.importCalls, 0);
      expect(service.exportCalls, 0);
      expect(service.scheduleCalls, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('import preview requires confirmation and blocks repeat picker', (
    tester,
  ) async {
    final service = _TransferService();
    final picker = Completer<File?>();
    var pickerCalls = 0;
    await tester.binding.setSurfaceSize(const Size(900, 700));
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackupDialog(
              service: service,
              chooseImport: () {
                pickerCalls++;
                return picker.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import SQLite'));
      await tester.pump();
      expect(pickerCalls, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Import SQLite'),
            )
            .onPressed,
        isNull,
      );
      picker.complete(File('portable.sqlite'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Imported backup'), findsOneWidget);
      expect(
        find.textContaining('replaces your current tasks, events'),
        findsOneWidget,
      );
      expect(service.scheduleCalls, 0);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(service.scheduleCalls, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    }
  });
}
