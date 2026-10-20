import 'package:flutter/widgets.dart';

/// The outlined orbit used for in-app Todorbit branding.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 24});

  static const asset = 'assets/todorbit_brand_mark.png';

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'Todorbit orbit logo',
  );
}
