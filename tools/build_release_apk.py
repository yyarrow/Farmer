#!/usr/bin/env python3
"""Build and verify a signed, non-debuggable Android release APK."""

from __future__ import annotations

import hashlib
import os
import re
import struct
import subprocess
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CREDENTIALS = ROOT / ".release" / "android-signing.env"
GODOT = ROOT / "tools" / "godot" / "Godot.app" / "Contents" / "MacOS" / "Godot"
APK = ROOT / "build" / "Qinghe-release.apk"
ELF_PT_LOAD = 1
ELF_PT_GNU_RELRO = 0x6474E552
ANDROID_16K_PAGE_SIZE = 16 * 1024


def load_credentials() -> dict[str, str]:
    if not CREDENTIALS.exists():
        raise SystemExit("Missing ignored release credentials. Run tools/create_release_keystore.py first.")
    values: dict[str, str] = {}
    for line in CREDENTIALS.read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            key, value = line.split("=", 1)
            values[key] = value
    return values


def android_tool(name: str) -> Path:
    sdk = Path(os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", "")))
    candidates = sorted((sdk / "build-tools").glob(f"*/{name}"))
    if not candidates:
        raise SystemExit(f"Cannot find Android build tool: {name}")
    return candidates[-1]


def inspect_native_libraries(archive: zipfile.ZipFile, names: set[str]) -> tuple[bool, bool, int]:
    """Check every packaged 64-bit ELF for 16 KB LOAD alignment and RELRO."""
    native_names = sorted(name for name in names if name.endswith(".so") and "/lib/arm64-v8a/" in f"/{name}")
    page_aligned = bool(native_names)
    relro_enabled = bool(native_names)
    for name in native_names:
        blob = archive.read(name)
        if len(blob) < 64 or blob[:6] != b"\x7fELF\x02\x01":
            page_aligned = False
            relro_enabled = False
            continue
        program_offset = struct.unpack_from("<Q", blob, 32)[0]
        entry_size = struct.unpack_from("<H", blob, 54)[0]
        entry_count = struct.unpack_from("<H", blob, 56)[0]
        if entry_size < 56 or entry_count == 0 or program_offset + entry_size * entry_count > len(blob):
            page_aligned = False
            relro_enabled = False
            continue
        load_count = 0
        has_relro = False
        for index in range(entry_count):
            header = struct.unpack_from("<IIQQQQQQ", blob, program_offset + index * entry_size)
            program_type = header[0]
            if program_type == ELF_PT_LOAD:
                load_count += 1
                if header[7] < ANDROID_16K_PAGE_SIZE:
                    page_aligned = False
            elif program_type == ELF_PT_GNU_RELRO:
                has_relro = True
        if load_count == 0:
            page_aligned = False
        if not has_relro:
            relro_enabled = False
    return page_aligned, relro_enabled, len(native_names)


def verify(apk: Path = APK) -> None:
    aapt = android_tool("aapt")
    apksigner = android_tool("apksigner")
    zipalign = android_tool("zipalign")
    badging = subprocess.run([aapt, "dump", "badging", apk], check=True, text=True, capture_output=True).stdout
    manifest = subprocess.run([aapt, "dump", "xmltree", apk, "AndroidManifest.xml"], check=True, text=True, capture_output=True).stdout
    permissions = subprocess.run([aapt, "dump", "permissions", apk], check=True, text=True, capture_output=True).stdout
    signature = subprocess.run([apksigner, "verify", "--verbose", "--print-certs", apk], check=True, text=True, capture_output=True).stdout
    with zipfile.ZipFile(apk) as archive:
        bad_entry = archive.testzip()
        names = set(archive.namelist())
        native_16k, native_relro, native_count = inspect_native_libraries(archive, names)
        themed_icon = (
            "res/mipmap-anydpi-v26/icon.xml" in names
            and b"monochrome" in archive.read("res/mipmap-anydpi-v26/icon.xml")
        )
    native_abis = sorted({name.split("/")[1] for name in names if name.startswith("lib/") and name.count("/") >= 2})
    zip_16k = subprocess.run(
        [zipalign, "-c", "-P", "16", "4", apk],
        text=True,
        capture_output=True,
    ).returncode == 0
    alias_start = manifest.find("E: activity-alias")
    alias_end = manifest.find("\n      E:", alias_start + 1) if alias_start >= 0 else -1
    launcher_alias = manifest[alias_start : alias_end if alias_end >= 0 else len(manifest)]
    checks = {
        "package": "package: name='com.qinghe.farmer'" in badging,
        "version": "versionCode='15' versionName='0.14.0'" in badging,
        "sdk": "sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging,
        "release": "application-debuggable" not in badging,
        "architecture": native_abis == ["arm64-v8a"] and "native-code: 'arm64-v8a'" in badging,
        "permissions": permissions.strip().splitlines() == ["package: com.qinghe.farmer", "uses-permission: name='android.permission.VIBRATE'"],
        "launcher": all(
            value in launcher_alias
            for value in ["GodotAppLauncher", "android:exported", "0xffffffff", "android.intent.action.MAIN", "android.intent.category.LAUNCHER"]
        ),
        "portrait": "android:screenOrientation" in manifest and "(type 0x10)0x1" in manifest,
        "game_category": "application-isGame" in badging,
        "signature": "Verified using v2 scheme (APK Signature Scheme v2): true" in signature,
        "identity": "CN=Qinghe Game" in signature and "CN=Godot" not in signature,
        "zip": bad_entry is None,
        "native_libraries": {
            "lib/arm64-v8a/libc++_shared.so",
            "lib/arm64-v8a/libgodot_android.so",
        }.issubset(names),
        "themed_icon": themed_icon,
        "elf_page_alignment_16k": native_16k,
        "elf_relro": native_relro,
        "zip_page_alignment_16k": zip_16k,
        "bundled_font": any("QingheSansSC-Medium" in name and name.endswith(".fontdata") for name in names),
        "font_license": any(name.endswith("assets/fonts/OFL.txt") for name in names),
        "store_excluded": not any("/store/" in name or "feature-graphic" in name for name in names),
        "development_files_excluded": not any(
            marker in f"/{name}" for name in names for marker in ("/tests/", "/docs/", "/tools/", "/.qa/")
        ),
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise SystemExit("ANDROID_RELEASE_FAILED " + ",".join(failed))
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    cert_match = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-f]+)", signature)
    cert = cert_match.group(1) if cert_match else "unknown"
    print(f"ANDROID_16K_OK apk={apk} libraries={native_count}")
    print(f"ANDROID_RELEASE_OK apk={apk} size_mb={apk.stat().st_size / 1048576:.1f}")
    print(f"APK_SHA256={digest}")
    print(f"SIGNER_SHA256={cert}")


def main() -> None:
    env = os.environ.copy()
    env.update(load_credentials())
    env["HOME"] = str(ROOT / ".home")
    APK.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [str(GODOT), "--headless", "--path", str(ROOT), "--export-release", "Android Release APK", str(APK)],
        cwd=ROOT,
        env=env,
        check=True,
    )
    verify()


if __name__ == "__main__":
    main()
