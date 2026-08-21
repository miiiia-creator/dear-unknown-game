#!/usr/bin/env python3
"""Cut the Chinese font down to the characters the game actually uses.

A complete Simplified Chinese face is 17-25 MB — several times the whole
web build. The game only ever draws a few hundred distinct characters, so the
font is subset to exactly those, plus the Latin and punctuation that appears
alongside them.

Re-run this whenever Chinese copy changes, or new text will render as tofu.

Run:  python3 tools/subset_font.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "cities.json")
UI_STRINGS = os.path.join(ROOT, "data", "translations.csv")
CODE = os.path.join(ROOT, "scripts")
# Kept out of the Godot import path: 17 MB of font the game never loads.
SRC = os.path.join(ROOT, "assets", "fonts", "source", "LXGWWenKai-Regular.ttf")
OUT = os.path.join(ROOT, "assets", "fonts", "LXGWWenKai-subset.ttf")

# Always keep these, whatever the copy currently says: digits and the marks the
# board draws, so a clue never turns into tofu.
ALWAYS = set(
    "0123456789"
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    " .,:;!?'\"()[]{}%&@#/\\|+-=_*~$"
    "×·—–…‘’“”　、。，：；！？（）《》【】"
)


def harvest(value, into):
    """Walk any JSON shape and collect every character in every string."""
    if isinstance(value, str):
        into.update(value)
    elif isinstance(value, dict):
        for v in value.values():
            harvest(v, into)
    elif isinstance(value, list):
        for v in value:
            harvest(v, into)


def main():
    if not os.path.exists(SRC):
        print("Missing %s — download LXGW WenKai first:\n"
              "  https://github.com/lxgw/LxgwWenKai/releases" % SRC, file=sys.stderr)
        return 1

    chars = set(ALWAYS)
    with open(DATA, encoding="utf-8") as f:
        harvest(json.load(f), chars)
    if os.path.exists(UI_STRINGS):
        with open(UI_STRINGS, encoding="utf-8") as f:
            harvest(f.read(), chars)

    # And the scripts, because not every Chinese character the game draws goes
    # through the translation table: the language switcher's own label is
    # "中文", which lives in palette.gd and is deliberately never translated.
    # Without this the button that turns Chinese on renders its first glyph as
    # tofu, which is the one place a player cannot afford one.
    for folder, _dirs, files in os.walk(CODE):
        for name in files:
            if name.endswith(".gd"):
                with open(os.path.join(folder, name), encoding="utf-8") as f:
                    harvest(f.read(), chars)

    # The pixel-art rows are just # and . — no need to carry them as glyphs.
    chars -= {"#"}
    text = "".join(sorted(chars))

    cmd = [
        sys.executable, "-m", "fontTools.subset", SRC,
        "--text=%s" % text,
        "--output-file=%s" % OUT,
        "--layout-features=*",
        "--no-hinting",
        "--desubroutinize",
        "--drop-tables+=DSIG",
    ]
    subprocess.run(cmd, check=True)

    before = os.path.getsize(SRC) / 1048576.0
    after = os.path.getsize(OUT) / 1024.0
    print("%d characters kept" % len(chars))
    print("%.1f MB  ->  %.0f KB" % (before, after))
    return 0


if __name__ == "__main__":
    sys.exit(main())
