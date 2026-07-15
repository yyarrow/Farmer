#!/usr/bin/env python3
"""Build and verify the signed Google Play Android App Bundle."""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import zipfile
from pathlib import Path

from build_release_apk import GODOT, ROOT, load_credentials, verify as verify_apk


AAB = ROOT / "build" / "Qinghe.aab"
APKS = ROOT / "build" / "Qinghe-universal.apks"
UNIVERSAL_APK = ROOT / "build" / "Qinghe-from-aab.apk"
BUNDLETOOL = ROOT / ".home" / "bundletool.jar"
ANDROID_TEMPLATE = ROOT / ".home" / "Library" / "Application Support" / "Godot" / "export_templates" / "4.7.stable" / "android_source.zip"
GRADLEW = ROOT / "android" / "build" / "gradlew"
ANDROID_MANIFEST = ROOT / "android" / "build" / "src" / "main" / "AndroidManifest.xml"
BUNDLETOOL_SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
ANDROID_TEMPLATE_SHA256 = "2dcb079f64b6cf9103cce273f42d1d5a4f52bc28d83a215579100fe568d6779c"


def require_sha256(path: Path, expected: str, label: str) -> None:
    if not path.exists():
        raise SystemExit(f"Missing {label}: {path}")
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"Unexpected {label} SHA-256: {actual}")


def java_tool(name: str) -> str:
    tool = shutil.which(name)
    if not tool:
        raise SystemExit(f"Missing Java tool: {name}. Select OpenJDK 17 first.")
    return tool


def enable_predictive_back() -> None:
    """Opt Play builds into Android's back dispatcher used by Godot 4.7."""
    if not ANDROID_MANIFEST.exists():
        raise SystemExit(f"Missing Android Gradle manifest: {ANDROID_MANIFEST}")
    text = ANDROID_MANIFEST.read_text(encoding="utf-8")
    attribute = 'android:enableOnBackInvokedCallback="true"'
    if attribute in text:
        return
    if "android:enableOnBackInvokedCallback=" in text:
        text = text.replace('android:enableOnBackInvokedCallback="false"', attribute, 1)
    else:
        marker = "    <application\n"
        if marker not in text:
            raise SystemExit("Cannot locate <application> in Android Gradle manifest")
        text = text.replace(marker, marker + f"        {attribute}\n", 1)
    ANDROID_MANIFEST.write_text(text, encoding="utf-8")


def verify() -> None:
    require_sha256(BUNDLETOOL, BUNDLETOOL_SHA256, "Google bundletool 1.18.3")
    with zipfile.ZipFile(AAB) as archive:
        bad_entry = archive.testzip()
        names = set(archive.namelist())
    required = {
        "base/manifest/AndroidManifest.xml",
        "base/dex/classes.dex",
        "base/lib/arm64-v8a/libgodot_android.so",
        "base/resources.pb",
    }
    native_abis = sorted({name.split("/")[2] for name in names if name.startswith("base/lib/") and name.count("/") >= 3})
    structural_checks = {
        "zip": bad_entry is None,
        "entries": required.issubset(names),
        "architecture": native_abis == ["arm64-v8a"],
        "signature_files": (
            any(name.upper().startswith("META-INF/") and name.upper().endswith(".SF") for name in names)
            and any(name.upper().startswith("META-INF/") and name.upper().endswith((".RSA", ".DSA", ".EC")) for name in names)
        ),
        "bundled_font": any("QingheSansSC-Medium" in name and name.endswith(".fontdata") for name in names),
        "font_license": any(name.endswith("assets/fonts/OFL.txt") for name in names),
        "store_excluded": not any("/store/" in name or "feature-graphic" in name for name in names),
    }
    failed = [name for name, passed in structural_checks.items() if not passed]
    if failed:
        raise SystemExit("ANDROID_AAB_FAILED " + ",".join(failed))

    clean_env = os.environ.copy()
    clean_env.update({"LC_ALL": "C", "LANG": "C"})
    java = java_tool("java")
    subprocess.run(
        [java, "-jar", str(BUNDLETOOL), "validate", f"--bundle={AAB}"],
        check=True,
        text=True,
        capture_output=True,
        env=clean_env,
    )
    manifest = subprocess.run(
        [java, "-jar", str(BUNDLETOOL), "dump", "manifest", f"--bundle={AAB}", "--module=base"],
        check=True,
        text=True,
        capture_output=True,
        env=clean_env,
    ).stdout
    manifest_checks = {
        "package": 'package="com.qinghe.farmer"' in manifest,
        "version": 'android:versionCode="6"' in manifest and 'android:versionName="0.5.0"' in manifest,
        "sdk": 'android:minSdkVersion="24"' in manifest and 'android:targetSdkVersion="36"' in manifest,
        "permission": 'android.permission.VIBRATE' in manifest and 'android.permission.INTERNET' not in manifest,
        "launcher": "com.godot.game.GodotAppLauncher" in manifest and "android.intent.category.LAUNCHER" in manifest,
        "portrait": 'android:screenOrientation="1"' in manifest or 'android:screenOrientation="portrait"' in manifest,
        "release": "android:debuggable=\"true\"" not in manifest,
        "predictive_back": 'android:enableOnBackInvokedCallback="true"' in manifest,
    }
    failed = [name for name, passed in manifest_checks.items() if not passed]
    if failed:
        raise SystemExit("ANDROID_AAB_FAILED " + ",".join(failed))

    jarsigner = java_tool("jarsigner")
    subprocess.run(
        [jarsigner, "-verify", "-verbose", "-certs", str(AAB)],
        check=True,
        text=True,
        capture_output=True,
        env=clean_env,
    )
    keytool = java_tool("keytool")
    certificate = subprocess.run(
        [keytool, "-printcert", "-jarfile", str(AAB)],
        check=True,
        text=True,
        capture_output=True,
        env=clean_env,
    ).stdout
    if "CN=Qinghe Game" not in certificate or "CN=Godot" in certificate:
        raise SystemExit("ANDROID_AAB_FAILED signature")

    digest = hashlib.sha256(AAB.read_bytes()).hexdigest()
    cert_digest = "unknown"
    for line in certificate.splitlines():
        if "SHA256:" in line:
            cert_digest = line.split("SHA256:", 1)[1].strip().replace(":", "").lower()
            break
    print("BUNDLETOOL_VALIDATE_OK")
    print(f"ANDROID_AAB_OK aab={AAB} size_mb={AAB.stat().st_size / 1048576:.1f} abis={','.join(native_abis)}")
    print(f"AAB_SHA256={digest}")
    print(f"SIGNER_SHA256={cert_digest}")


def build_universal_apk(credentials: dict[str, str]) -> None:
    """Build the same universal APK set Play would derive, without printing secrets."""
    for output in (APKS, UNIVERSAL_APK):
        output.unlink(missing_ok=True)
    password = credentials["GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"]
    command = [
        java_tool("java"),
        "-jar",
        str(BUNDLETOOL),
        "build-apks",
        f"--bundle={AAB}",
        f"--output={APKS}",
        "--mode=universal",
        f"--ks={credentials['GODOT_ANDROID_KEYSTORE_RELEASE_PATH']}",
        f"--ks-key-alias={credentials['GODOT_ANDROID_KEYSTORE_RELEASE_USER']}",
        f"--ks-pass=pass:{password}",
        f"--key-pass=pass:{password}",
    ]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        safe_detail = (detail[-1] if detail else "unknown bundletool error").replace(password, "<REDACTED>")
        raise SystemExit(f"ANDROID_APKS_FAILED {safe_detail}")
    with zipfile.ZipFile(APKS) as archive:
        bad_entry = archive.testzip()
        names = set(archive.namelist())
        if bad_entry is not None or "universal.apk" not in names:
            raise SystemExit("ANDROID_APKS_FAILED structure")
        with archive.open("universal.apk") as source, UNIVERSAL_APK.open("wb") as destination:
            shutil.copyfileobj(source, destination)
    verify_apk(UNIVERSAL_APK)
    print(f"ANDROID_APKS_OK apks={APKS} universal_apk={UNIVERSAL_APK}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--universal-apk",
        action="store_true",
        help="also derive and verify a universal APK with bundletool for device QA",
    )
    args = parser.parse_args()
    env = os.environ.copy()
    credentials = load_credentials()
    env.update(credentials)
    env["HOME"] = str(ROOT / ".home")
    env["GRADLE_USER_HOME"] = str(ROOT / ".home" / ".gradle")
    AAB.parent.mkdir(parents=True, exist_ok=True)
    if not GRADLEW.exists():
        require_sha256(ANDROID_TEMPLATE, ANDROID_TEMPLATE_SHA256, "Godot 4.7 Android source template")
        subprocess.run(
            [str(GODOT), "--headless", "--path", str(ROOT), "--install-android-build-template"],
            cwd=ROOT,
            env=env,
            check=True,
        )
    elif (ROOT / "android" / ".build_version").read_text(encoding="utf-8").strip() != "4.7.stable":
        raise SystemExit("Installed Android build template does not match Godot 4.7.stable")
    enable_predictive_back()
    command = [
        str(GODOT),
        "--headless",
        "--path",
        str(ROOT),
        "--export-release",
        "Android Release AAB",
        str(AAB),
    ]
    subprocess.run(command, cwd=ROOT, env=env, check=True)
    verify()
    if args.universal_apk:
        build_universal_apk(credentials)


if __name__ == "__main__":
    main()
