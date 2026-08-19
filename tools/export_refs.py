#!/usr/bin/env python3
"""Render composition reference sheets for the painted postcards.

One PNG per city showing which discoveries belong in that city's painting and
roughly where, at the same positions the reveal animation places them. Hand the
sheet to whoever (or whatever) paints the postcard so the artwork and the pixel
pieces line up.

Run:  python3 tools/export_refs.py
"""

from __future__ import annotations

import json
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "cities.json")
OUT_DIR = os.path.join(ROOT, "build", "art_refs")

W, H = 1440, 1080

# Which discoveries belong in the landscape, and where. Everything else in a
# city is an object rather than scenery — food, souvenirs — and is collected in
# the journal instead of standing in the painting.
#
# (puzzle_id, centre_x, baseline_y, width) as fractions of the frame.
# Composition comes from the built content so the sheets and the game can never
# disagree about which subjects belong in a city's painting.
def hex_to_rgb(value: str):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def blend(bottom, top, alpha):
    return tuple(int(round(b + (t - b) * alpha)) for b, t in zip(bottom, top))


class Canvas:
    def __init__(self, w, h, fill):
        self.w, self.h = w, h
        self.px = [list(fill) * w for _ in range(h)]

    def rect(self, x, y, w, h, colour, alpha=1.0):
        for yy in range(max(0, int(y)), min(self.h, int(y + h))):
            row = self.px[yy]
            for xx in range(max(0, int(x)), min(self.w, int(x + w))):
                base = row[xx * 3:xx * 3 + 3]
                r, g, b = blend(base, colour, alpha)
                row[xx * 3], row[xx * 3 + 1], row[xx * 3 + 2] = r, g, b

    def vgradient(self, top_colour, bottom_colour):
        for yy in range(self.h):
            t = yy / (self.h - 1)
            c = blend(top_colour, bottom_colour, t)
            self.px[yy] = list(c) * self.w

    def png(self, path):
        raw = b"".join(b"\x00" + bytes(row) for row in self.px)
        def chunk(tag, payload):
            body = tag + payload
            return (struct.pack(">I", len(payload)) + body
                    + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF))
        ihdr = struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0)
        with open(path, "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n")
            f.write(chunk(b"IHDR", ihdr))
            f.write(chunk(b"IDAT", zlib.compress(raw, 6)))
            f.write(chunk(b"IEND", b""))


def draw_art(canvas, art, cx, base_y, width_frac, colour):
    h = len(art)
    w = len(art[0])
    cell = max(1, int(canvas.w * width_frac / w))
    total_w, total_h = w * cell, h * cell
    ox = int(canvas.w * cx - total_w / 2)
    oy = int(canvas.h * base_y - total_h)
    for r, row in enumerate(art):
        for c, ch in enumerate(row):
            if ch == "#":
                canvas.rect(ox + c * cell, oy + r * cell, cell, cell, colour)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    cities = json.load(open(DATA, encoding="utf-8"))["cities"]
    by_id = {c["id"]: c for c in cities}

    for city in cities:
        city_id = city["id"]
        slots = [(s["id"], s["x"], s["base"], s["w"]) for s in city.get("composition", [])]
        if not slots:
            continue
        puzzles = {p["id"]: p for p in city["puzzles"]}
        paper = hex_to_rgb(city["palette"][0])
        accent = hex_to_rgb(city["palette"][1])
        deep = hex_to_rgb(city["palette"][2])

        canvas = Canvas(W, H, paper)
        # A hint of the dusk ramp so the reference reads as a sky, not a sheet.
        canvas.vgradient(blend(deep, paper, 0.45), blend(paper, (255, 255, 255), 0.4))
        # Ground line where the pieces stand.
        canvas.rect(0, H * 0.66, W, 3, accent, 0.5)
        # The band the game prints its title over — nothing important goes here.
        canvas.rect(0, H * 0.70, W, H * 0.30, paper, 0.35)

        names = []
        for pid, cx, base, wf in slots:
            p = puzzles[pid]
            draw_art(canvas, p["art"], cx, base, wf, deep)
            names.append(p["name"])

        path = os.path.join(OUT_DIR, "%s_composition.png" % city_id)
        canvas.png(path)
        print("%-9s %s" % (city_id, " | ".join(names)))
        print("          -> %s" % path)


if __name__ == "__main__":
    main()
