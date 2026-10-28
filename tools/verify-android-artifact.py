"""Check ZIP and ELF alignment of every native library in an Android APK/AAB.

APK ZIP alignment is required only for uncompressed libraries. This does not
replace installation/launch tests on a 16 KiB-page emulator or physical device.
"""
import argparse
import struct
import zipfile


def verify(artifact):
    failures = []
    count = 0
    libraries_by_abi = {}
    with zipfile.ZipFile(artifact) as archive, open(artifact, "rb") as raw:
        for info in archive.infolist():
            if not info.filename.endswith(".so"):
                continue
            count += 1
            parts = info.filename.split("/")
            if "lib" in parts:
                directory = parts.index("lib")
                if len(parts) > directory + 2:
                    libraries_by_abi.setdefault(parts[directory + 1], set()).add(parts[-1])
            data = archive.read(info)
            if data[:4] != b"\x7fELF":
                failures.append(f"{info.filename}: invalid ELF")
                continue
            endian = "<" if data[5] == 1 else ">"
            is64 = data[4] == 2
            phoff = struct.unpack_from(endian + ("Q" if is64 else "I"), data, 32 if is64 else 28)[0]
            entry_size, entries = struct.unpack_from(endian + "HH", data, 54 if is64 else 42)
            for i in range(entries):
                offset = phoff + i * entry_size
                if struct.unpack_from(endian + "I", data, offset)[0] != 1:
                    continue
                alignment = struct.unpack_from(endian + ("Q" if is64 else "I"), data, offset + (48 if is64 else 28))[0]
                if alignment < 16384:
                    failures.append(f"{info.filename}: PT_LOAD alignment {alignment}")
            if str(artifact).lower().endswith(".apk") and info.compress_type == zipfile.ZIP_STORED:
                raw.seek(info.header_offset + 26)
                name_len, extra_len = struct.unpack("<HH", raw.read(4))
                data_offset = info.header_offset + 30 + name_len + extra_len
                if data_offset % 16384:
                    failures.append(f"{info.filename}: ZIP data offset {data_offset} is not 16 KiB aligned")
    if not count:
        failures.append("No native libraries found")
    for abi, libraries in libraries_by_abi.items():
        if "libflutter.so" not in libraries:
            failures.append(f"{abi}: native dependencies are packaged without the Flutter engine")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"Verified {count} native libraries: ELF and applicable APK ZIP alignment pass.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact")
    verify(parser.parse_args().artifact)
