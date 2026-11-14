import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/shared/scroll_edge_fade.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'scroll edge hint follows overflow and passes pointer input ($brightness)',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 200,
                child: ScrollEdgeFade(
                  child: ListView(
                    controller: controller,
                    children: [
                      const SizedBox(height: 172),
                      TextButton(
                        onPressed: () => pressed = true,
                        child: const Text('Reachable'),
                      ),
                      const SizedBox(height: 500),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('scroll-bottom-fade')),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(160, 190));
        await tester.pump();
        expect(pressed, isTrue);
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('scroll-bottom-fade')), findsNothing);
        expect(find.byKey(const ValueKey('scroll-top-fade')), findsOneWidget);
        controller.jumpTo(0);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('scroll-bottom-fade')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('scroll-top-fade')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('custom topFadeColor and bottomFadeColor are rendered in gradients', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const customBottom = Color(0x33000000);
    const customTop = Color(0x22000000);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 200,
            child: ScrollEdgeFade(
              topFadeColor: customTop,
              bottomFadeColor: customBottom,
              child: ListView(
                controller: controller,
                children: const [
                  SizedBox(height: 100),
                  SizedBox(height: 500),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bottomFadeFinder = find.byKey(const ValueKey('scroll-bottom-fade'));
    expect(bottomFadeFinder, findsOneWidget);

    final bottomBox = tester.widget<DecoratedBox>(bottomFadeFinder);
    final bottomGrad = (bottomBox.decoration as BoxDecoration).gradient as LinearGradient;
    expect(bottomGrad.colors.last, customBottom);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    final topFadeFinder = find.byKey(const ValueKey('scroll-top-fade'));
    expect(topFadeFinder, findsOneWidget);

    final topBox = tester.widget<DecoratedBox>(topFadeFinder);
    final topGrad = (topBox.decoration as BoxDecoration).gradient as LinearGradient;
    expect(topGrad.colors.first, customTop);
  });
}
