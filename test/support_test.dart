import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/support_introduction_store.dart';
import 'package:life_manager/features/support/support_button.dart';

void main() {
  test(
    'support introduction is profile-local and survives reopening',
    () async {
      final folder = await Directory.systemTemp.createTemp('todorbit-support-');
      addTearDown(() => folder.delete(recursive: true));
      final file = File.fromUri(folder.uri.resolve('support.json'));
      expect(await SupportIntroductionStore(file).claim(), isTrue);
      final bytes = await file.readAsBytes();
      expect(await SupportIntroductionStore(file).claim(), isFalse);
      expect(await file.readAsBytes(), bytes);
      await file.writeAsString('{"version":999}');
      expect(await SupportIntroductionStore(file).claim(), isFalse);
      expect(await file.readAsString(), '{"version":999}');
    },
  );

  testWidgets(
    'official support action always opens the authorized PayPal URL',
    (tester) async {
      const channel = MethodChannel('life_manager/file_dialog');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SupportDialog())),
      );
      await tester.tap(find.text('Buy Me a Coffee'));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'openResource');
      expect(calls.single.arguments, 'https://paypal.me/2hussam4');
      expect(find.text('Support via PayPal'), findsOneWidget);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'support popup is optional, scrollable and closable ($brightness)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const Scaffold(body: SupportButton()),
          ),
        );
        expect(find.text('Enjoying Todorbit?'), findsNothing);
        await tester.tap(find.byTooltip('Support Todorbit'));
        await tester.pumpAndSettle();
        expect(find.text('Enjoying Todorbit?'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Enjoying Todorbit?'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('browser failure stays recoverable inside the popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportDialog(
            open: () async => throw PlatformException(code: 'failed'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buy Me a Coffee'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open your browser'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('introduction lasts four seconds without opening a modal', (
    tester,
  ) async {
    var claims = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportButton(
            reducedMotion: true,
            claimIntroduction: () async {
              claims++;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final state = find.byType(DecoratedBox).last;
    Color? highlight() =>
        (tester.widget<DecoratedBox>(state).decoration as BoxDecoration).color;
    expect(highlight(), isNot(Colors.transparent));
    expect(find.text('Enjoying Todorbit?'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(highlight(), Colors.transparent);
    expect(claims, 1);
  });
}
