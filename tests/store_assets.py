#!/usr/bin/env python3
"""Validate Google Play listing assets with only the Python standard library."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "store"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_info(path: Path) -> tuple[int, int, int, int]:
    data = path.read_bytes()
    if data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
        raise AssertionError(f"not a PNG: {path.relative_to(ROOT)}")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
    return width, height, bit_depth, color_type


def require_png(path: Path, size: tuple[int, int], color_type: int, max_bytes: int) -> None:
    width, height, bit_depth, actual_color_type = png_info(path)
    assert (width, height) == size, f"wrong dimensions: {path.relative_to(ROOT)}"
    assert bit_depth == 8, f"wrong bit depth: {path.relative_to(ROOT)}"
    assert actual_color_type == color_type, f"wrong PNG color type: {path.relative_to(ROOT)}"
    assert path.stat().st_size <= max_bytes, f"file too large: {path.relative_to(ROOT)}"


def section(markdown: str, heading: str) -> str:
    marker = f"## {heading}\n"
    start = markdown.index(marker) + len(marker)
    remainder = markdown[start:]
    end = remainder.find("\n## ")
    return (remainder if end < 0 else remainder[:end]).strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict-contact", action="store_true", help="fail while legal/contact placeholders remain")
    args = parser.parse_args()

    require_png(STORE / "icon-512.png", (512, 512), 6, 1_048_576)
    require_png(STORE / "feature-graphic.png", (1024, 500), 2, 8_388_608)
    screenshots = sorted((STORE / "screenshots").glob("*.png"))
    assert len(screenshots) >= 5, "the release set must cover seasons, military intelligence and governance"
    for screenshot in screenshots:
        require_png(screenshot, (1080, 1920), 2, 8_388_608)

    listing = (STORE / "listing-zh-CN.md").read_text(encoding="utf-8")
    title = section(listing, "应用名称")
    short = section(listing, "简短说明")
    full = section(listing, "完整说明")
    assert 1 <= len(title) <= 30, "Play title must be 1-30 characters"
    assert 1 <= len(short) <= 80, "Play short description must be 1-80 characters"
    assert 1 <= len(full) <= 4000, "Play full description must be 1-4000 characters"

    release_notes = (STORE / "release-notes-zh-CN.txt").read_text(encoding="utf-8").strip()
    assert 1 <= len(release_notes) <= 500, "release notes must be 1-500 characters"
    privacy = (STORE / "privacy-policy.md").read_text(encoding="utf-8")
    readme = (STORE / "README.md").read_text(encoding="utf-8")
    assert "140 个字符" in readme and "图片替代文字" in readme, "screenshot alt text is missing"

    placeholder_count = listing.count("【待填写】") + privacy.count("【发布前填写")
    if args.strict_contact:
        assert placeholder_count == 0, "replace legal name, support email and privacy URL placeholders before publishing"
    print(
        "STORE_ASSETS_OK "
        f"images={2 + len(screenshots)} title={len(title)} short={len(short)} full={len(full)} "
        f"release_notes={len(release_notes)} placeholders={placeholder_count}"
    )


if __name__ == "__main__":
    main()
