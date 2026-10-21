import 'package:flutter/material.dart';

import '../../domain/task_view_preferences.dart';

class CompositionText extends StatefulWidget {
  const CompositionText({
    super.key,
    required this.text,
    required this.display,
    this.style,
  });

  final String text;
  final CompositionTextDisplay display;
  final TextStyle? style;

  @override
  State<CompositionText> createState() => _CompositionTextState();
}

class _CompositionTextState extends State<CompositionText> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = widget.display == CompositionTextDisplay.compact;
      final style = widget.style ?? Theme.of(context).textTheme.bodyMedium;
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
      )..layout(maxWidth: constraints.maxWidth);
      final hasMore = compact && painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionArea(
            child: Text(
              widget.text,
              style: style,
              maxLines: compact && !expanded ? 2 : null,
              overflow: compact && !expanded ? TextOverflow.ellipsis : null,
            ),
          ),
          if (hasMore)
            TextButton(
              onPressed: () => setState(() => expanded = !expanded),
              child: Text(expanded ? 'Show less' : 'Show more'),
            ),
        ],
      );
    },
  );
}
