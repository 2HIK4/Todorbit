/// Download sizes use IEC units (1024 bytes per KiB), capped at TiB.
/// Negative sizes are invalid; a non-positive total means unknown.
String formatDownloadSize(int bytes, {int? total}) {
  if (bytes < 0) return 'Unknown size';
  final reference = total != null && total > 0 ? total : bytes;
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var unit = 0;
  var divisor = 1;
  while (reference / divisor >= 1024 && unit < units.length - 1) {
    divisor *= 1024;
    unit++;
  }
  String value(int size) =>
      '${(size / divisor).toStringAsFixed(unit == 0 ? 0 : 2)} ${units[unit]}';
  return total != null && total > 0
      ? '${value(bytes)} / ${value(total)}'
      : value(bytes);
}
