# Calendar event icons

These 31 glyphs are a modified subset of Google's Material Icons font shipped
with Flutter 3.47.7. They match `lib/features/shared/icon_picker.dart` plus the
default outlined event glyph. Attribution and terms are in [LICENSE.txt](LICENSE.txt),
copied from Flutter's font artifact. The license is distributed with the companion.

Regenerate with `python tools/dev/update-native-event-icons.py <flutter-sdk>`.
This uses Flutter's existing font-subset tool and adds no runtime dependency.
The native painter embeds the subset so companion-only launches do not depend
on Flutter's tree-shaken font assets or installed Windows icon fonts.
