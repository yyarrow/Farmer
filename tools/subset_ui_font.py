#!/usr/bin/env python3
"""Build the deterministic Qinghe UI font subset from official Noto Sans SC."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / ".home" / "font-source" / "NotoSansSC-Variable.ttf"
DEFAULT_OUTPUT = ROOT / "assets" / "fonts" / "QingheSansSC-Medium.ttf"
SOURCE_SHA256 = "a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da"


def build_charset() -> set[str]:
    chars = {chr(codepoint) for codepoint in range(0x20, 0x7F)}
    for lead in range(0xA1, 0xF8):
        for trail in range(0xA1, 0xFF):
            try:
                chars.update(bytes((lead, trail)).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    for path in [*sorted((ROOT / "src").glob("*.gd")), ROOT / "project.godot", ROOT / "main.tscn"]:
        chars.update(path.read_text(encoding="utf-8"))
    return {char for char in chars if ord(char) >= 0x20}


def rename_font(font: TTFont) -> None:
    names = font["name"]
    replacements = {
        1: "Qinghe Sans SC",
        2: "Medium",
        4: "Qinghe Sans SC Medium",
        6: "QingheSansSC-Medium",
        16: "Qinghe Sans SC",
        17: "Medium",
    }
    for name_id, value in replacements.items():
        names.setName(value, name_id, 3, 1, 0x0409)
        names.setName(value, name_id, 1, 0, 0)
    font["OS/2"].usWeightClass = 500


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("output", nargs="?", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    source_bytes = args.source.read_bytes()
    source_hash = hashlib.sha256(source_bytes).hexdigest()
    if source_hash != SOURCE_SHA256:
        raise SystemExit(f"Unexpected Noto Sans SC source hash: {source_hash}")

    variable = TTFont(args.source, recalcBBoxes=False, recalcTimestamp=False)
    font = instantiateVariableFont(variable, {"wght": 500}, inplace=False, optimize=True)
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recalc_timestamp = False
    subsetter = subset.Subsetter(options=options)
    charset = build_charset()
    subsetter.populate(unicodes={ord(char) for char in charset})
    subsetter.subset(font)
    rename_font(font)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    font.save(args.output, reorderTables=True)

    output_hash = hashlib.sha256(args.output.read_bytes()).hexdigest()
    with TTFont(args.output, lazy=True) as result:
        glyph_count = len(result.getGlyphOrder())
    print(
        "FONT_SUBSET_OK "
        f"chars={len(charset)} glyphs={glyph_count} size_kb={args.output.stat().st_size / 1024:.1f} sha256={output_hash}"
    )


if __name__ == "__main__":
    main()
