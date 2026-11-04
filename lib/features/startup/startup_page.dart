import 'package:flutter/material.dart';

/// Bounded, scrollable startup content remains reachable before the app opens.
class StartupPage extends StatelessWidget {
  const StartupPage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}
