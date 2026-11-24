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
  static const double breakpointSidebar = 760;
  static const double breakpointMedium = 1050;
  static const double breakpointWide = 1200;

  // Page and container insets
  static const double pageInsetH = 20;
  static const double pageInsetV = 16;
  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(
    pageInsetH,
    pageInsetV,
    pageInsetH,
    AppSpacing.related,
  );

  // Side panel dimensions
  static const double panelMinWidth = 320;
  static const double panelDefaultWidth = 370;
  static const double panelWideWidth = 440;
  static const double panelMaxWidth = 560;
  static const double panelResizeHandle = 16;
  static const double workspaceMinWidth = 420;
  static const double workspaceMaxWidth = 800;
  static const double taskListMaxWidth = 1120;
  // Standard FAB, its edge gap, and clearance for the final row.
  static const double taskListFabClearance =
      56 + AppSpacing.content * 2 + AppSpacing.related;
  static const double editorPageMaxWidth = 680;
  static const double editorFieldMinWidth = 190;

  // Dialog dimensions
  static const double dialogMinWidth = 320;
  static const double dialogDefaultWidth = 520;
  static const double dialogWideWidth = 600;
  static const double dialogDefaultHeight = 620;
  static const double dialogMaxHeight = 680;

  // Minimum accessible tap / click target size
  static const double minTapTarget = 48;
}

/// Shared corner radii for controls and contained surfaces.
abstract final class AppRadius {
  static const double control = 8;
  static const double surface = 10;
  static const double dialog = 14;
}

/// Sizes for Todorbit's Material glyphs. Interactive targets size separately.
abstract final class AppIconSize {
  static const double inline = 16;
  static const double navigation = 20;
  static const double action = 20;
}
