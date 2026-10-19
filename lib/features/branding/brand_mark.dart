import 'package:flutter/widgets.dart';

/// The outlined orbit used for in-app TodoPilot branding.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 24});

  static const asset = 'assets/todopilot_brand_mark.png';

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'TodoPilot orbit logo',
  );
}
