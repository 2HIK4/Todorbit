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

/// Centralized layout breakpoints and dimensions for consistent responsive behavior.
abstract final class AppLayout {
  // Breakpoints
  static const double breakpointCompact = 600;
  static const double breakpointMedium = 1050;
  static const double breakpointWide = 1200;

  // Page and container insets
  static const double pageInsetH = 20;
  static const double pageInsetV = 16;
  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(20, 16, 20, 12);

  // Side panel dimensions
  static const double panelMinWidth = 320;
  static const double panelDefaultWidth = 370;
  static const double panelWideWidth = 440;
  static const double panelMaxWidth = 560;

  // Dialog dimensions
  static const double dialogMinWidth = 320;
  static const double dialogDefaultWidth = 520;
  static const double dialogWideWidth = 600;
  static const double dialogDefaultHeight = 620;
  static const double dialogMaxHeight = 680;

  // Minimum accessible tap / click target size
  static const double minTapTarget = 48;
}
