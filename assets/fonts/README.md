# Noto Sans SC

`QingheSansSC-Medium.ttf` is a static 500-weight subset derived from the Noto Sans SC variable font distributed by the official Google Fonts repository. It contains all GB2312 characters plus every character currently used by the game.

- Source: `https://github.com/google/fonts/tree/main/ofl/notosanssc`
- Original source SHA-256: `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`
- Subset SHA-256: `d81caf103f6c6873531415bccd7c1c022a402eeb8086604ab22f1adb1365dbda`
- Rebuild: `PYTHONPATH=.home/pydeps python3 tools/subset_ui_font.py`
- Copyright: © 2014–2021 Adobe, with Reserved Font Name “Source”
- License: SIL Open Font License 1.1; the complete text is in `OFL.txt`.

The modified font is renamed “Qinghe Sans SC” and remains under SIL OFL 1.1. The game embeds it to make Simplified Chinese text deterministic on Android devices that do not ship a CJK system font while keeping download size and runtime memory bounded.
