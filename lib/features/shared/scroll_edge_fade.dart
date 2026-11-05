import 'package:flutter/material.dart';

class FadingListView extends StatelessWidget {
  const FadingListView({
    super.key,
    required this.children,
    this.padding,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
  }) : builder = null,
       count = null;
  const FadingListView.builder({
    super.key,
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    this.padding,
    this.controller,
    this.physics,
  }) : builder = itemBuilder,
       count = itemCount,
       children = const [],
       shrinkWrap = false;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final bool shrinkWrap;
  final IndexedWidgetBuilder? builder;
  final int? count;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) => ScrollEdgeFade(
    child: builder != null
        ? ListView.builder(
            controller: controller,
            physics: physics,
            padding: padding,
            itemCount: count,
            itemBuilder: builder!,
          )
        : ListView(
            controller: controller,
            physics: physics,
            shrinkWrap: shrinkWrap,
            padding: padding,
            children: children,
          ),
  );
}

class FadingScrollView extends StatelessWidget {
  const FadingScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => ScrollEdgeFade(
    child: SingleChildScrollView(
      controller: controller,
      padding: padding,
      child: child,
    ),
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
  bool moreAbove = false;
  bool pending = false;
  bool next = false;
  bool nextAbove = false;

  void update(ScrollMetrics metrics, int depth) {
    if (depth != 0 || metrics.axis != Axis.vertical) return;
    next = metrics.extentAfter > 1;
    nextAbove = metrics.extentBefore > 1;
    if (pending) return;
    pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pending = false;
      if (mounted && (moreBelow != next || moreAbove != nextAbove)) {
        setState(() {
          moreBelow = next;
          moreAbove = nextAbove;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<_ScrollEdgeOwner>() !=
        null) {
      return widget.child;
    }
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
        child: _ScrollEdgeOwner(
          child: Stack(
            children: [
              widget.child,
              if (moreAbove)
                Positioned(
                  left: 0,
                  right: 12,
                  top: 0,
                  height: 12,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        key: const ValueKey('scroll-top-fade'),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              background,
                              background.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                            colors: [
                              background.withValues(alpha: 0),
                              background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScrollEdgeOwner extends InheritedWidget {
  const _ScrollEdgeOwner({required super.child});
  @override
  bool updateShouldNotify(_ScrollEdgeOwner oldWidget) => false;
}
