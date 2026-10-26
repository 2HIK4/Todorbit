import 'dart:convert';
import 'dart:io';

// Device/profile-local discovery state, excluded from portable settings transfer.
class SupportIntroductionStore {
  SupportIntroductionStore(this.file);
  final File file;

  Future<bool> claim() async {
    // Any existing receipt, including an unknown format, suppresses the hint.
    // Never replace an unreadable or newer preference with defaults.
    if (await file.exists()) return false;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.$pid.tmp');
    try {
      await temporary.writeAsString(
        jsonEncode({
          'version': 1,
          'shown': true,
          'shownAtUtc': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      await temporary.rename(file.path);
      return true;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
