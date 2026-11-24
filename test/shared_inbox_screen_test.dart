import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/shared_inbox_store.dart';
import 'package:life_manager/domain/shared_inbox_entry.dart';
import 'package:life_manager/features/shared_inbox/shared_inbox_screen.dart';
import 'package:life_manager/features/workspace/windows_resource_dialog.dart';

class _FakeResourceDialog extends WindowsResourceDialog {
  String? openedTarget;
  @override
  Future<void> open(String target) async {
    openedTarget = target;
  }
}

void main() {
  late Directory tempDir;
  late SharedInboxStore store;
  late _FakeResourceDialog fakeDialog;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('todorbit_screen_test_');
    store = SharedInboxStore(tempDir);
    fakeDialog = _FakeResourceDialog();
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Widget createSubject() {
    return MaterialApp(
      home: SharedInboxScreen(store: store, resourceDialog: fakeDialog),
    );
  }

  Future<void> pumpSubject(WidgetTester tester) async {
    await tester.pumpWidget(createSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('renders empty state when inbox has no files', (tester) async {
    await pumpSubject(tester);

    expect(find.text('Shared Files'), findsOneWidget);
    expect(find.text('No shared files yet'), findsOneWidget);
    expect(
      find.textContaining('Sharing files does not automatically create tasks.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'displays list of shared files with names, sizes, and categories',
    (tester) async {
      await tester.runAsync(() async {
        await store.addBytes(
          [1, 2, 3, 4],
          displayName: 'Contract.pdf',
          mimeType: 'application/pdf',
        );
        await store.addBytes(
          List.filled(2048, 7),
          displayName: 'Receipt.png',
          mimeType: 'image/png',
        );
      });

      await pumpSubject(tester);

      expect(find.text('Contract.pdf'), findsOneWidget);
      expect(find.text('Receipt.png'), findsOneWidget);
      expect(find.textContaining('2 file'), findsOneWidget);
      expect(find.text('PDFs'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
    },
  );

  testWidgets(
    'compact file metadata wraps and category empty state is accurate',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(
        () => store.addBytes(
          [1, 2, 3],
          displayName: 'Quarterly planning notes for the entire team.pdf',
          mimeType: 'application/pdf',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: SharedInboxScreen(store: store, resourceDialog: fakeDialog),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('On-device only · Not synced').hitTestable(),
        findsOneWidget,
      );
      final images = find.widgetWithText(FilterChip, 'Images');
      await tester.ensureVisible(images);
      await tester.pumpAndSettle();
      await tester.tap(images);
      await tester.pumpAndSettle();
      expect(
        find.text('No matching shared files').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search filters files by displayName', (tester) async {
    await tester.runAsync(() async {
      await store.addBytes([1, 2], displayName: 'Meeting_Notes.txt');
      await store.addBytes([3, 4], displayName: 'Quarterly_Plan.pdf');
    });

    await pumpSubject(tester);

    expect(find.text('Meeting_Notes.txt'), findsOneWidget);
    expect(find.text('Quarterly_Plan.pdf'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'quarter');
    await tester.pumpAndSettle();

    expect(find.text('Meeting_Notes.txt'), findsNothing);
    expect(find.text('Quarterly_Plan.pdf'), findsOneWidget);
  });

  testWidgets('filter chips filter by category', (tester) async {
    await tester.runAsync(() async {
      await store.addBytes(
        [1, 2],
        displayName: 'Doc.pdf',
        mimeType: 'application/pdf',
      );
      await store.addBytes(
        [3, 4],
        displayName: 'Pic.jpg',
        mimeType: 'image/jpeg',
      );
    });

    await pumpSubject(tester);

    // Tap Images filter chip
    await tester.tap(find.text('Images'));
    await tester.pumpAndSettle();

    expect(find.text('Doc.pdf'), findsNothing);
    expect(find.text('Pic.jpg'), findsOneWidget);

    // Tap PDFs filter chip
    await tester.tap(find.text('PDFs'));
    await tester.pumpAndSettle();

    expect(find.text('Doc.pdf'), findsOneWidget);
    expect(find.text('Pic.jpg'), findsNothing);
  });

  testWidgets('tapping file opens it via resourceDialog', (tester) async {
    late final SharedInboxEntry entry;
    await tester.runAsync(() async {
      entry = await store.addBytes([1, 2, 3], displayName: 'Presentation.pdf');
    });

    await pumpSubject(tester);

    await tester.tap(find.text('Presentation.pdf'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(fakeDialog.openedTarget, entry.fileIn(tempDir).path);
  });

  testWidgets(
    'single file deletion shows confirmation dialog and removes item',
    (tester) async {
      await tester.runAsync(() async {
        await store.addBytes([1, 2], displayName: 'Obsolete.pdf');
      });

      await pumpSubject(tester);

      expect(find.text('Obsolete.pdf'), findsOneWidget);

      // Open popup menu
      await tester.tap(find.byTooltip('File actions'));
      await tester.pumpAndSettle();

      // Tap delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Delete from Shared Inbox?'), findsOneWidget);
      expect(
        find.textContaining(
          'Any copies already attached to tasks will remain intact.',
        ),
        findsOneWidget,
      );

      // Confirm delete
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('Obsolete.pdf'), findsNothing);
      expect(find.text('No shared files yet'), findsOneWidget);
    },
  );

  testWidgets('selection mode supports batch selection and deletion', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await store.addBytes([1], displayName: 'FileA.pdf');
      await store.addBytes([2], displayName: 'FileB.pdf');
      await store.addBytes([3], displayName: 'FileC.pdf');
    });

    await pumpSubject(tester);

    // Enter selection mode
    await tester.tap(find.byTooltip('Select files'));
    await tester.pumpAndSettle();

    expect(find.text('0 selected'), findsOneWidget);

    // Select all
    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();

    expect(find.text('3 selected'), findsOneWidget);

    // Tap Delete selected
    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();

    expect(find.text('Delete 3 shared files?'), findsOneWidget);

    // Confirm batch delete
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final remaining = await tester.runAsync(() => store.load());
    expect(remaining?.isEmpty, isTrue);
    expect(find.text('No shared files yet'), findsOneWidget);
  });
}
