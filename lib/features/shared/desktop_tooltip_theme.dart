import 'package:flutter/material.dart';

/// Supplemental desktop hints share palette colors and a deliberate hover delay.
TooltipThemeData desktopTooltipTheme(ColorScheme scheme) => TooltipThemeData(
  waitDuration: const Duration(milliseconds: 600),
  exitDuration: const Duration(milliseconds: 100),
  showDuration: const Duration(seconds: 5),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  margin: const EdgeInsets.all(8),
  textStyle: TextStyle(color: scheme.onSurface, fontSize: 12, height: 1.4),
  decoration: BoxDecoration(
    color: scheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: scheme.outlineVariant),
  ),
);
