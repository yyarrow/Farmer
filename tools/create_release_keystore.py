#!/usr/bin/env python3
"""Create a private Android upload key inside the ignored .release directory."""

from __future__ import annotations

import os
import secrets
import shutil
import string
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_DIR = ROOT / ".release"
KEYSTORE = RELEASE_DIR / "qinghe-upload.keystore"
CREDENTIALS = RELEASE_DIR / "android-signing.env"
ALIAS = "qinghe"


def main() -> None:
    if KEYSTORE.exists() or CREDENTIALS.exists():
        raise SystemExit("Release credentials already exist; refusing to replace the app signing identity.")
    keytool = shutil.which("keytool")
    if not keytool:
        raise SystemExit("keytool was not found; install or select OpenJDK 17 first.")
    alphabet = string.ascii_letters + string.digits
    password = "".join(secrets.choice(alphabet) for _ in range(48))
    RELEASE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    subprocess.run(
        [
            keytool,
            "-genkeypair",
            "-v",
            "-keystore",
            str(KEYSTORE),
            "-storetype",
            "PKCS12",
            "-storepass",
            password,
            "-keypass",
            password,
            "-alias",
            ALIAS,
            "-keyalg",
            "RSA",
            "-keysize",
            "4096",
            "-validity",
            "10000",
            "-dname",
            "CN=Qinghe Game,OU=Release,O=Qinghe,C=CN",
            "-noprompt",
        ],
        check=True,
    )
    credentials = "\n".join(
        [
            f"GODOT_ANDROID_KEYSTORE_RELEASE_PATH={KEYSTORE}",
            f"GODOT_ANDROID_KEYSTORE_RELEASE_USER={ALIAS}",
            f"GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD={password}",
            "",
        ]
    )
    CREDENTIALS.write_text(credentials, encoding="utf-8")
    os.chmod(KEYSTORE, 0o600)
    os.chmod(CREDENTIALS, 0o600)
    print(f"ANDROID_KEYSTORE_OK keystore={KEYSTORE} credentials={CREDENTIALS}")
    print("Back up both ignored files securely; losing them can prevent future signed updates.")


if __name__ == "__main__":
    main()
