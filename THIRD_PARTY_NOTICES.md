# Third-party notices

The Windows bundle includes Flutter and package license notices generated at `data/flutter_assets/NOTICES.Z`. Keep that file in both installer and portable distributions. Dependencies and resolved versions are in `pubspec.lock` and `experiments/widget-shell-probe/widget-shell-probe.csproj`.

The self-contained native widget contains .NET 10 runtime and Windows Desktop components. Their license files and runtime third-party notices, copied from the 10.0.6 runtime packs, are bundled in `third_party/`. Review and refresh those files when updating the .NET runtime pack. `Microsoft.Data.Sqlite` is MIT licensed; `SQLitePCLRaw` is Apache-2.0 licensed, and its license and upstream notice are also in `third_party/`. SQLite itself is public domain. These notices apply to the external components and do not change the Todorbit project license.

The Todorbit orbit mark in `assets/todorbit_icon.svg`, the PNG, and the Windows ICO is adapted from the [Lucide orbit icon](https://lucide.dev/icons/orbit). Its geometry is retained, with a black rounded tile and white strokes for the application icon. Lucide's ISC license applies to this icon:

Copyright (c) 2026 Lucide Icons and Contributors

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Apple Human Interface Guidelines were used as design references; no Apple assets or reference files are included in the distribution.
