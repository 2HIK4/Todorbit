import 'dart:io';
import 'dart:convert';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const reviewCaptureKey = ValueKey('uiux-review-capture');
String? loadedReviewFont;

const reviewDisplayConfigurations = [
  (size: Size(360, 800), scale: 1.0, brightness: Brightness.light),
  (size: Size(393, 852), scale: 1.0, brightness: Brightness.light),
  (size: Size(360, 800), scale: 1.0, brightness: Brightness.dark),
  (size: Size(393, 852), scale: 1.0, brightness: Brightness.dark),
  (size: Size(393, 852), scale: 1.5, brightness: Brightness.dark),
  (size: Size(320, 850), scale: 2.0, brightness: Brightness.dark),
];

Future<void> loadReviewFonts() async {
  final configFile = File('.dart_tool/package_config.json');
  final packages =
      (jsonDecode(configFile.readAsStringSync()) as Map)['packages'] as List;
  final flutterPackage = packages.cast<Map>().singleWhere(
    (p) => p['name'] == 'flutter',
  );
  final sdk = Directory.fromUri(
    configFile.uri.resolve(flutterPackage['rootUri'] as String),
  ).parent.parent;
  final materialFonts = sdk.uri.resolve('bin/cache/artifacts/material_fonts/');
  for (final entry in {
    'Roboto':
        Platform.environment['UIUX_CAPTURE_FONT'] ??
        File.fromUri(materialFonts.resolve('roboto-regular.ttf')).path,
    'MaterialIcons':
        Platform.environment['UIUX_CAPTURE_ICONS'] ??
        File.fromUri(materialFonts.resolve('materialicons-regular.otf')).path,
  }.entries) {
    if (entry.key == 'Roboto') loadedReviewFont = entry.value;
    final loader = FontLoader(entry.key)
      ..addFont(
        Future.value(ByteData.sublistView(File(entry.value).readAsBytesSync())),
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
    'fontFile': loadedReviewFont,
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
