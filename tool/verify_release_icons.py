"""Verify every built-in picker icon exists in the packaged Release font."""

from pathlib import Path
import re
import shutil
import struct
import sys


ROOT = Path(__file__).resolve().parents[1]
FLUTTER = shutil.which("flutter")
if FLUTTER is None:
    sys.exit("Flutter SDK not found on PATH")
SDK = Path(FLUTTER).resolve().parents[1]
ICONS_SOURCE = (SDK / "packages/flutter/lib/src/material/icons.dart").read_text()
PICKER_SOURCE = (ROOT / "lib/features/shared/icon_picker.dart").read_text()
FONT = ROOT / "build/windows/x64/runner/Release/data/flutter_assets/fonts/MaterialIcons-Regular.otf"

names = re.findall(r"'[^']+': Icons\.([A-Za-z0-9_]+)", PICKER_SOURCE)
codepoints = {
    name: int(value, 16)
    for name, value in re.findall(
        r"static const IconData (\w+) = IconData\(0x([0-9a-f]+), fontFamily: 'MaterialIcons'\)",
        ICONS_SOURCE,
    )
}
data = FONT.read_bytes()
table_count = struct.unpack_from(">H", data, 4)[0]
tables = {
    data[12 + i * 16 : 16 + i * 16].decode(): struct.unpack_from(">II", data, 20 + i * 16)
    for i in range(table_count)
}
offset = tables["cmap"][0]
encoding_count = struct.unpack_from(">H", data, offset + 2)[0]
available = set()
for i in range(encoding_count):
    subtable_offset = struct.unpack_from(">I", data, offset + 8 + i * 8)[0]
    pos = offset + subtable_offset
    format_number = struct.unpack_from(">H", data, pos)[0]
    if format_number == 4:
        segments = struct.unpack_from(">H", data, pos + 6)[0] // 2
        ends = pos + 14
        starts = ends + segments * 2 + 2
        deltas = starts + segments * 2
        ranges = deltas + segments * 2
        for segment in range(segments):
            first = struct.unpack_from(">H", data, starts + segment * 2)[0]
            last = struct.unpack_from(">H", data, ends + segment * 2)[0]
            delta = struct.unpack_from(">h", data, deltas + segment * 2)[0]
            range_offset = struct.unpack_from(">H", data, ranges + segment * 2)[0]
            for character in range(first, last + 1):
                if character == 0xFFFF:
                    continue
                glyph = (
                    (character + delta) & 0xFFFF
                    if range_offset == 0
                    else struct.unpack_from(
                        ">H", data, ranges + segment * 2 + range_offset + 2 * (character - first)
                    )[0]
                )
                if glyph:
                    available.add(character)
    elif format_number == 12:
        groups = struct.unpack_from(">I", data, pos + 12)[0]
        for group in range(groups):
            first, last, _ = struct.unpack_from(">III", data, pos + 16 + group * 12)
            available.update(range(first, last + 1))

missing = [name for name in names if codepoints.get(name) not in available]
print(f"Release icon coverage: {len(names) - len(missing)}/{len(names)} picker icons")
if missing:
    sys.exit("Missing glyphs: " + ", ".join(missing))
