import 'package:flutter/material.dart';

/// Shared logical-pixel rhythm for grouped controls and page sections.
abstract final class AppSpacing {
  static const double small = 4;
  static const double gap = 8;
  static const double related = 12;
  static const double content = 16;
  static const double section = 24;

  static EdgeInsetsGeometry editorScrollPadding(
    BuildContext context, {
    double bottom = related,
  }) => EdgeInsetsDirectional.fromSTEB(
    0,
    gap,
    Theme.of(context).platform == TargetPlatform.android ? 0 : 14,
    bottom,
  );
}
