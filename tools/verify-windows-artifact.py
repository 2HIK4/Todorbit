#!/usr/bin/env python3
"""
Todorbit Developer Automation Toolkit - Windows Artifact & Binary Verifier
Audits Windows release PE binaries, DLL imports, CRT dependencies, and package archives.
"""

import os
import sys
import json
import struct
import zipfile
import re
from pathlib import Path

IMAGE_FILE_MACHINE_AMD64 = 0x8664
IMAGE_NT_OPTIONAL_HDR64_MAGIC = 0x020B
DEBUG_CRT_DLLS = {
    "msvcp140d.dll", "vcruntime140d.dll", "vcruntime140_1d.dll",
    "ucrtbased.dll", "msvcr120d.dll", "msvcr110d.dll"
}

def parse_pe_info(file_path):
    with open(file_path, "rb") as f:
        dos_hdr = f.read(64)
        if len(dos_hdr) < 64 or dos_hdr[:2] != b"MZ":
            return {"error": "Not a valid DOS/MZ executable"}
        
        e_lfanew = struct.unpack_from("<I", dos_hdr, 60)[0]
        f.seek(e_lfanew)
        pe_sig = f.read(4)
        if pe_sig != b"PE\0\0":
            return {"error": "Invalid PE signature"}
        
        coff_hdr = f.read(20)
        machine, num_sections, timedate, symtab, num_syms, opt_hdr_size, characteristics = struct.unpack("<HHIIIHH", coff_hdr)
        
        if machine != IMAGE_FILE_MACHINE_AMD64:
            return {"error": f"Invalid architecture: machine type 0x{machine:04x} (expected 0x8664 x64)"}
        
        opt_hdr = f.read(opt_hdr_size)
        if len(opt_hdr) < 2:
            return {"error": "Truncated optional header"}
        
        magic = struct.unpack_from("<H", opt_hdr, 0)[0]
        if magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC:
            return {"error": f"Invalid optional header magic: 0x{magic:04x} (expected 0x020B PE32+)"}
        
        subsystem = struct.unpack_from("<H", opt_hdr, 68)[0] if len(opt_hdr) >= 70 else None
        
        # Parse data directories (import table is directory 1)
        # In PE32+, data directories start at offset 112 (after 16 standard fields + 4 RVA fields + 8 PE32+ fields)
        import_rva, import_size = 0, 0
        if len(opt_hdr) >= 120:
            import_rva, import_size = struct.unpack_from("<II", opt_hdr, 112 + 8 * 1)
        
        # Read sections
        f.seek(e_lfanew + 24 + opt_hdr_size)
        sections = []
        for _ in range(num_sections):
            sec = f.read(40)
            if len(sec) < 40:
                break
            sec_name = sec[:8].decode("latin1").strip("\x00")
            vsize, vaddr, raw_size, raw_offset = struct.unpack_from("<IIII", sec, 8)
            sections.append({
                "name": sec_name,
                "vaddr": vaddr,
                "vsize": vsize,
                "raw_size": raw_size,
                "raw_offset": raw_offset,
            })
        
        # Resolve imports
        imported_dlls = []
        if import_rva and import_size:
            sec_target = None
            for s in sections:
                if s["vaddr"] <= import_rva < s["vaddr"] + s["vsize"]:
                    sec_target = s
                    break
            
            if sec_target:
                f_offset = sec_target["raw_offset"] + (import_rva - sec_target["vaddr"])
                f.seek(f_offset)
                while True:
                    desc = f.read(20)
                    if len(desc) < 20 or desc == b"\0" * 20:
                        break
                    ilt_rva, timestamp, forwarder, name_rva, iat_rva = struct.unpack("<IIIII", desc)
                    if not name_rva:
                        break
                    # Resolve name
                    curr_pos = f.tell()
                    name_offset = sec_target["raw_offset"] + (name_rva - sec_target["vaddr"])
                    f.seek(name_offset)
                    raw_name = b""
                    while b"\0" not in raw_name:
                        chunk = f.read(16)
                        if not chunk:
                            break
                        raw_name += chunk
                    dll_name = raw_name.split(b"\0")[0].decode("ascii", errors="replace").lower()
                    imported_dlls.append(dll_name)
                    f.seek(curr_pos)
        
        # Detect debug CRT
        debug_crt_found = [dll for dll in imported_dlls if dll in DEBUG_CRT_DLLS]
        
        return {
            "file": os.path.basename(file_path),
            "valid_pe": True,
            "architecture": "x64 (AMD64)",
            "subsystem": subsystem,
            "imported_dlls": imported_dlls,
            "debug_crt_detected": debug_crt_found,
            "passed": len(debug_crt_found) == 0,
        }

def verify_inno_setup_script(iss_path, repo_root):
    if not os.path.exists(iss_path):
        return {"valid": False, "error": f"Inno Setup script not found: {iss_path}"}
    
    with open(iss_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    
    # Check AppId
    app_id_match = re.search(r"AppId=([^\r\n]+)", content)
    app_id = app_id_match.group(1).strip() if app_id_match else None
    
    # Verify required referenced files
    referenced_files = ["THIRD_PARTY_NOTICES.md", "LICENSE", "windows/runner/resources/app_icon.ico"]
    missing_files = []
    for rf in referenced_files:
        full_p = os.path.join(repo_root, rf)
        if not os.path.exists(full_p):
            missing_files.append(rf)
    
    # Check 64-bit architecture configuration
    x64_allowed = "ArchitecturesAllowed=x64compatible" in content
    x64_mode = "ArchitecturesInstallIn64BitMode=x64compatible" in content
    
    passed = (app_id is not None) and (len(missing_files) == 0) and x64_allowed and x64_mode
    return {
        "script": os.path.relpath(iss_path, repo_root),
        "app_id": app_id,
        "x64_configured": x64_allowed and x64_mode,
        "missing_references": missing_files,
        "passed": passed
    }

def verify_portable_archive(zip_path):
    if not os.path.exists(zip_path):
        return {"valid": False, "error": f"Archive not found: {zip_path}"}
    
    extraneous = []
    total_files = 0
    has_exe = False
    
    with zipfile.ZipFile(zip_path, "r") as zf:
        for info in zf.infolist():
            total_files += 1
            fname = info.filename.lower()
            if fname.endswith(".exe"):
                has_exe = True
            for bad_ext in [".pdb", ".ilk", ".obj", ".sqlite", ".db"]:
                if fname.endswith(bad_ext):
                    extraneous.append(info.filename)
    
    passed = has_exe and len(extraneous) == 0
    return {
        "archive": os.path.basename(zip_path),
        "total_files": total_files,
        "has_executable": has_exe,
        "extraneous_files": extraneous,
        "passed": passed
    }

def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Verify Windows installer config and compiled PE binaries."
    )
    parser.add_argument(
        "--config-only",
        action="store_true",
        help="Exit 0 when config passes and zero artifacts are present (unless any present artifact failed).",
    )
    args = parser.parse_args()

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    iss_path = os.path.join(repo_root, "installer", "life_manager.iss")

    inno_setup = verify_inno_setup_script(iss_path, repo_root)
    config_passed = bool(inno_setup.get("passed", False))
    binaries_audited = []

    # Check any compiled release binaries if present
    release_dir = os.path.join(repo_root, "build", "windows", "x64", "runner", "Release")
    if os.path.exists(release_dir):
        for root, _, files in os.walk(release_dir):
            for file in files:
                if file.lower().endswith((".exe", ".dll")):
                    p = os.path.join(root, file)
                    res = parse_pe_info(p)
                    binaries_audited.append(res)

    artifacts_inspected = len(binaries_audited)
    artifacts_passed = artifacts_inspected > 0 and all(
        r.get("passed", False) for r in binaries_audited
    )
    if not config_passed or (artifacts_inspected > 0 and not artifacts_passed):
        artifact_status = "FAILED"
    elif artifacts_inspected == 0:
        artifact_status = "MISSING_ARTIFACTS"
    else:
        artifact_status = "VERIFIED"

    overall_passed = config_passed and artifacts_passed

    report = {
        "inno_setup": inno_setup,
        "binaries_audited": binaries_audited,
        "config_passed": config_passed,
        "artifacts_inspected": artifacts_inspected,
        "artifacts_passed": artifacts_passed,
        "artifact_status": artifact_status,
        "overall_passed": overall_passed,
    }

    print(json.dumps(report, indent=2))
    if args.config_only:
        ok = config_passed and (artifacts_inspected == 0 or artifacts_passed)
    else:
        ok = overall_passed
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
