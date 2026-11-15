import 'dart:io';
import 'dart:convert';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const reviewCaptureKey = ValueKey('uiux-review-capture');

const reviewDisplayConfigurations = [
  (size: Size(360, 800), scale: 1.0, brightness: Brightness.light),
  (size: Size(393, 852), scale: 1.0, brightness: Brightness.light),
  (size: Size(360, 800), scale: 1.0, brightness: Brightness.dark),
  (size: Size(393, 852), scale: 1.0, brightness: Brightness.dark),
  (size: Size(393, 852), scale: 1.5, brightness: Brightness.dark),
  (size: Size(320, 850), scale: 2.0, brightness: Brightness.dark),
];

Future<void> loadReviewFonts() async {
  for (final entry in {
    'Roboto': Platform.environment['UIUX_CAPTURE_FONT'],
    'MaterialIcons': Platform.environment['UIUX_CAPTURE_ICONS'],
  }.entries) {
    if (entry.value == null) continue;
    final loader = FontLoader(entry.key)
      ..addFont(
        Future.value(
          ByteData.sublistView(File(entry.value!).readAsBytesSync()),
        ),
      );
    await loader.load();
  }
}

Future<void> captureReview(WidgetTester tester, String name) async {
  final directory = Platform.environment['UIUX_CAPTURE_DIR'];
  if (directory == null) return;
  final context = tester.element(find.byType(Scaffold).first);
  final media = MediaQuery.of(context);
  final metadata = {
    'capture': name,
    'provenance': 'observed Flutter test view and inherited configuration',
    'logicalWidth': media.size.width,
    'logicalHeight': media.size.height,
    'devicePixelRatio': media.devicePixelRatio,
    'textScaler': media.textScaler.toString(),
    'textScaleAt16sp': media.textScaler.scale(16) / 16,
    'theme': Theme.of(context).brightness.name,
    'locale': Localizations.localeOf(context).toLanguageTag(),
    'fontFile': Platform.environment['UIUX_CAPTURE_FONT'],
    'captureType':
        'offscreen Flutter widget test; no OS chrome or real Android runtime',
  };
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(reviewCaptureKey),
    );
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      await File('$directory/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      await File('$directory/$name.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(metadata));
    } finally {
      image.dispose();
    }
  });
}
