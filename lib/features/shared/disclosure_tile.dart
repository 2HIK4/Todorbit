import 'package:flutter/material.dart';

// Expansion state is a bool; editable/selectable descendants store double
// scroll offsets. Their own bucket keeps those values from sharing a key.
class DisclosureTile extends StatefulWidget {
  const DisclosureTile({
    super.key,
    required this.title,
    required this.children,
    this.tilePadding,
  });
  final Widget title;
  final List<Widget> children;
  final EdgeInsetsGeometry? tilePadding;
  @override
  State<DisclosureTile> createState() => _DisclosureTileState();
}

class _DisclosureTileState extends State<DisclosureTile> {
  final storage = PageStorageBucket();
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: widget.title,
    tilePadding: widget.tilePadding,
    children: [
      PageStorage(
        bucket: storage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.children,
        ),
      ),
    ],
  );
}
