import 'package:flutter/material.dart';

class FadingListView extends StatelessWidget {
  const FadingListView({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ScrollEdgeFade(
    child: ListView(padding: padding, children: children),
  );
}

class FadingScrollView extends StatelessWidget {
  const FadingScrollView({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ScrollEdgeFade(
    child: SingleChildScrollView(padding: padding, child: child),
  );
}

/// A pointer-transparent hint that disappears when the scroll viewport ends.
class ScrollEdgeFade extends StatefulWidget {
  const ScrollEdgeFade({super.key, required this.child});
  final Widget child;

  @override
  State<ScrollEdgeFade> createState() => _ScrollEdgeFadeState();
}

class _ScrollEdgeFadeState extends State<ScrollEdgeFade> {
  bool moreBelow = false;
  bool pending = false;
  bool next = false;

  void update(ScrollMetrics metrics, int depth) {
    if (depth != 0 || metrics.axis != Axis.vertical) return;
    next = metrics.extentAfter > 1;
    if (pending) return;
    pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pending = false;
      if (mounted && moreBelow != next) setState(() => moreBelow = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        theme.dialogTheme.backgroundColor ??
        theme.colorScheme.surfaceContainerHigh;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notice) {
        update(notice.metrics, notice.depth);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notice) {
          update(notice.metrics, notice.depth);
          return false;
        },
        child: Stack(
          children: [
            widget.child,
            if (moreBelow)
              Positioned(
                left: 0,
                right: 12,
                bottom: 0,
                height: 18,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: DecoratedBox(
                      key: const ValueKey('scroll-bottom-fade'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [background.withValues(alpha: 0), background],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
