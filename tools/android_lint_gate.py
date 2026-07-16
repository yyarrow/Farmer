#!/usr/bin/env python3
"""Run Android lint and reject every issue outside the pinned Godot template set."""

from __future__ import annotations

import os
import subprocess
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ANDROID_BUILD = ROOT / "android" / "build"
GRADLEW = ANDROID_BUILD / "gradlew"
REPORT = ANDROID_BUILD / "build" / "reports" / "lint-results-standardRelease.xml"
THEMES = ANDROID_BUILD / "res" / "values" / "themes.xml"

EXPECTED = Counter(
    {
        "NewApi": 1,
        "UnusedAttribute": 5,
        "LockedOrientationActivity": 1,
        "NonResizeableActivity": 1,
        "DiscouragedApi": 3,
        "ObsoleteSdkInt": 5,
        "IconDuplicatesConfig": 4,
        "IconLocation": 1,
    }
)


def main() -> None:
    if not GRADLEW.exists():
        raise SystemExit("Missing Android Gradle template. Run tools/build_release_aab.py first.")
    env = os.environ.copy()
    env["HOME"] = str(ROOT / ".home")
    env["GRADLE_USER_HOME"] = str(ROOT / ".home" / ".gradle")
    subprocess.run(
        [str(GRADLEW), "-p", str(ANDROID_BUILD), "lintStandardRelease", "--no-daemon"],
        cwd=ROOT,
        env=env,
        check=True,
    )
    if not REPORT.exists():
        raise SystemExit(f"ANDROID_LINT_GATE_FAILED missing_report={REPORT}")

    issues = ET.parse(REPORT).getroot().findall("issue")
    counts = Counter(issue.attrib.get("id", "") for issue in issues)
    if counts != EXPECTED:
        detail = ",".join(f"{name}:{count}" for name, count in sorted(counts.items()))
        raise SystemExit(f"ANDROID_LINT_GATE_FAILED unexpected_issues={detail}")

    errors = [issue for issue in issues if issue.attrib.get("severity") in {"Error", "Fatal"}]
    new_api = errors[0] if len(errors) == 1 else None
    locations = new_api.findall("location") if new_api is not None else []
    exact_template_issue = (
        new_api is not None
        and new_api.attrib.get("id") == "NewApi"
        and new_api.attrib.get("message")
        == "`android:windowSplashScreenBackground` requires API level 31 (current min is 24)"
        and len(locations) == 1
        and Path(locations[0].attrib.get("file", "")) == THEMES
    )
    theme_text = THEMES.read_text(encoding="utf-8") if THEMES.exists() else ""
    compatible_splash = (
        '<item name="android:windowSplashScreenBackground">@mipmap/icon_background</item>' in theme_text
        and '<item name="windowSplashScreenBackground">@mipmap/icon_background</item>' in theme_text
    )
    if not exact_template_issue or not compatible_splash:
        raise SystemExit("ANDROID_LINT_GATE_FAILED splash_compatibility")

    warning_count = sum(count for name, count in counts.items() if name != "NewApi")
    print(f"ANDROID_LINT_GATE_OK warnings={warning_count} pinned_template_issue=NewApi")


if __name__ == "__main__":
    main()
