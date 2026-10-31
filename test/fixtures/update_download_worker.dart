import 'dart:io';

import 'package:life_manager/data/resumable_update_download.dart';

Future<void> main(List<String> args) async {
  final transfer = ResumableUpdateDownload(
    approved: (uri) => uri.host == '127.0.0.1',
  );
  await transfer.download(
    uri: Uri.parse(args[0]),
    target: File(args[1]),
    size: int.parse(args[2]),
    digest: args[3],
    version: '1.0.20+24',
    progress: (received, _) {
      if (received > 0) stdout.writeln(received);
    },
  );
}
