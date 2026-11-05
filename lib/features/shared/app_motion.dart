import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const duration = Duration(milliseconds: 180);
  static AnimationStyle style(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(
          duration: duration,
          reverseDuration: duration,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
}

class AppMotionTheme extends StatelessWidget {
  const AppMotionTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      expansionTileTheme: Theme.of(context).expansionTileTheme
          .copyWith(expansionAnimationStyle: AppMotion.style(context)),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final entry in const PageTransitionsTheme().builders.entries)
            entry.key: _MotionPageTransition(entry.value),
        },
      ),
    ),
    child: child,
  );
}

class _MotionPageTransition extends PageTransitionsBuilder {
  const _MotionPageTransition(this.standard);
  final PageTransitionsBuilder standard;
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : standard.buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}
