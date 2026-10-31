import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/shared/download_size.dart';

void main() {
  test('decimal units and boundaries', () {
    for (final entry in <int, String>{
      0: '0 B',
      999: '999 B',
      1000: '1 KB',
      756000: '756 KB',
      1000000: '1 MB',
      51529687: '51.5 MB',
      1000000000: '1 GB',
      1000000000000: '1 TB',
    }.entries) {
      expect(formatDownloadSize(entry.key), entry.value);
    }
    expect(formatDownloadSize(-1), 'Unknown size');
    expect(formatDownloadSize(18600000, total: 51529687), '18.6 MB / 51.5 MB');
    expect('${formatDownloadSize(2400000)}/s', '2.4 MB/s');
    expect(formatDownloadSize(0, total: 1000000), '0 MB / 1 MB');
  });
}
