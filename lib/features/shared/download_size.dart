/// Decimal file sizes, with one fractional digit and no trailing zero.
String formatDownloadSize(int bytes, {int? total}) {
  if (bytes < 0) return 'Unknown size';
  final reference = total != null && total > 0 ? total : bytes;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var unit = 0;
  var divisor = 1;
  while (reference / divisor >= 1000 && unit < units.length - 1) {
    divisor *= 1000;
    unit++;
  }
  String value(int size) =>
      '${(size / divisor).toStringAsFixed(unit == 0 ? 0 : 1).replaceFirst(RegExp(r'\.0$'), '')} ${units[unit]}';
  return total != null && total > 0
      ? '${value(bytes)} / ${value(total)}'
      : value(bytes);
}
