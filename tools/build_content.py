#!/usr/bin/env python3
"""Authoring tool for Around the World.

Holds the pixel-art source for every discovery, validates that each grid makes a
Nonogram with exactly one solution reachable by pure line logic (no guessing),
and writes data/cities.json which the game loads at runtime.

Run:  python3 tools/build_content.py
"""

from __future__ import annotations

import json
import os
import sys
from functools import lru_cache
from itertools import combinations

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "cities.json")


# --------------------------------------------------------------------------
# Content
# --------------------------------------------------------------------------

def P(pid, name, emoji, category, art):
    """One discovery. No prose: the writing lives in the city letters now, so a
    reveal shows what you found and gets out of the way."""
    return {
        "id": pid,
        "name": name,
        "emoji": emoji,
        "category": category,
        "art": [row for row in art.strip().splitlines()],
    }


TOKYO = [
    P("tokyo_fuji", "Mount Fuji", "🗻", "Nature", """
..#..
.###.
.###.
#####
#####
"""),
    P("tokyo_lantern", "Paper Lantern", "🏮", "Cultural object", """
.###.
#####
#####
#####
.###.
"""),
    P("tokyo_torii", "Torii Gate", "⛩", "Architecture", """
##########
##########
..#....#..
##########
##########
..#....#..
..#....#..
..#....#..
..#....#..
.###..###.
"""),
    P("tokyo_ramen", "Ramen", "🍜", "Food", """
..#....#..
.#......#.
..#....#..
..........
##########
##########
.########.
..######..
...####...
..........
"""),
    P("tokyo_onigiri", "Onigiri", "🍙", "Food", """
....##....
...####...
..######..
..######..
.########.
.########.
##.####.##
##.####.##
##########
##########
"""),
    P("tokyo_shinkansen", "Shinkansen", "🚄", "Transportation", """
..........
...#######
..########
.#.####.##
##########
##########
##########
.########.
..##..##..
..........
"""),
    P("tokyo_sakura", "Cherry Blossom", "🌸", "Nature", """
.##....##.
####..####
.##.##.##.
....##....
..######..
..######..
....##....
.##.##.##.
####..####
.##....##.
"""),
    P("tokyo_tower", "Tokyo Tower", "🗼", "Landmark", """
.......#.......
.......#.......
......###......
......#.#......
.....#####.....
.....#...#.....
....#######....
....#.....#....
...##.....##...
...#.......#...
..###########..
..##.......##..
.###.......###.
.##.........##.
###############
"""),
]

PARIS = [
    P("paris_wine", "Glass of Wine", "🍷", "Food", """
#####
.###.
..#..
..#..
#####
"""),
    P("paris_brie", "Wedge of Brie", "🧀", "Food", """
....#
...##
..###
.####
#####
"""),
    P("paris_croissant", "Croissant", "🥐", "Food", """
....###...
..#####...
.####.##..
.###...##.
.##....##.
.##....##.
.###...##.
.####.##..
..#####...
....###...
"""),
    P("paris_macaron", "Macaron", "🍬", "Food", """
..######..
.########.
.########.
..........
##########
##########
..........
.########.
.########.
..######..
"""),
    P("paris_cafe", "Café Crème", "☕", "Everyday life", """
...#..#...
..#..#....
...#..#...
..........
########..
#######.#.
#######.#.
#######.#.
########..
.######...
"""),
    P("paris_arc", "Arc de Triomphe", "🏛", "Architecture", """
##########
##########
##########
###....###
##......##
##......##
##......##
##......##
##......##
##......##
"""),
    P("paris_louvre", "Glass Pyramid", "🔺", "Architecture", """
....##....
....##....
...####...
...####...
..######..
..######..
.########.
.########.
##########
##########
"""),
    P("paris_eiffel", "Eiffel Tower", "🗼", "Landmark", """
.......#.......
......###......
......###......
.....#####.....
.....##.##.....
....##...##....
....#######....
....##...##....
...###...###...
...##.....##...
..###.....###..
..#####.#####..
.####.#.#.####.
.###..#.#..###.
###...#.#...###
"""),
]

ROME = [
    P("rome_gelato", "Gelato", "🍦", "Food", """
.###.
#####
.###.
..#..
..#..
"""),
    P("rome_column", "Roman Column", "🏛", "Architecture", """
#####
.###.
.###.
.###.
#####
"""),
    P("rome_pizza", "Pizza al Taglio", "🍕", "Food", """
....##....
...####...
...####...
..######..
..#.##.#..
.########.
.###..###.
.########.
##########
##########
"""),
    P("rome_pasta", "Cacio e Pepe", "🍝", "Food", """
..........
.#.#..#.#.
..#.##.#..
.#.#..#.#.
##########
.########.
.########.
..######..
...####...
..........
"""),
    P("rome_vespa", "Vespa", "🛵", "Transportation", """
.......##.
......####
..#######.
.########.
##########
##########
.########.
##......##
#.#....#.#
##......##
"""),
    P("rome_fountain", "Fountain", "⛲", "Landmark", """
....##....
...####...
..##..##..
.##....##.
....##....
....##....
..######..
.########.
##########
##########
"""),
    P("rome_amphora", "Amphora", "🏺", "Cultural object", """
..######..
..#....#..
...####...
..######..
.########.
##########
##########
.########.
..######..
...####...
"""),
    P("rome_colosseum", "Colosseum", "🏟", "Landmark", """
...#########...
..###########..
.#############.
###.#.#.#.#.###
###.#.#.#.#.###
###############
###.#.#.#.#.###
###.#.#.#.#.###
###############
##.#.#.#.#.#.##
##.#.#.#.#.#.##
###############
#.#.#.#.#.#.#.#
#.#.#.#.#.#.#.#
###############
"""),
]

NEW_YORK = [
    P("ny_apple", "The Big Apple", "🍎", "Cultural object", """
..#..
.###.
#####
#####
.###.
"""),
    P("ny_walkup", "Walk-Up Window", "🏢", "Everyday life", """
.###.
.#.#.
.###.
.#.#.
#####
"""),
    P("ny_taxi", "Yellow Cab", "🚕", "Transportation", """
....##....
....##....
..######..
.########.
##########
##########
.########.
##......##
#.#....#.#
##......##
"""),
    P("ny_skyline", "Skyline", "🌆", "Architecture", """
.#........
.#..#.....
.#..#..##.
###.#..##.
###.##.##.
###.##.###
#####.####
#####.####
##########
##########
"""),
    P("ny_traffic", "Traffic Light", "🚦", "Everyday life", """
..######..
.########.
.##....##.
.########.
.##....##.
.########.
.##....##.
.########.
..######..
....##....
"""),
    P("ny_bagel", "Bagel", "🥯", "Food", """
...####...
..######..
.###..###.
###....###
###....###
###....###
###....###
.###..###.
..######..
...####...
"""),
    P("ny_hotdog", "Street Cart Hot Dog", "🌭", "Food", """
..........
..#....#..
.########.
##########
#.######.#
##########
.########.
..#....#..
..........
..........
"""),
    P("ny_liberty", "Statue of Liberty", "🗽", "Landmark", """
...........##..
...........##..
..#.#.#.#..##..
..#######..##..
...#####...##..
....###...###..
....###..####..
....#########..
....#######....
...#########...
...#########...
..###########..
..###########..
.#############.
###############
"""),
]

LONDON = [
    P("london_tea", "Cup of Tea", "🫖", "Everyday life", """
#####
#####
#####
.###.
..#..
"""),
    P("london_rain", "Passing Shower", "🌧", "Nature", """
.###.
#####
.....
#.#.#
.#.#.
"""),
    P("london_bus", "Double-Decker", "🚌", "Transportation", """
.########.
##########
#.##.##.##
##########
##########
#.##.##.##
##########
##########
.##....##.
.##....##.
"""),
    P("london_phonebox", "Phone Box", "☎", "Cultural object", """
.########.
##########
.########.
.##.##.##.
.##.##.##.
.##.##.##.
.##.##.##.
.##.##.##.
.########.
##########
"""),
    P("london_umbrella", "Umbrella", "☂", "Everyday life", """
...####...
..######..
.########.
##########
##########
....##....
....##....
....##....
....##..#.
....####..
"""),
    P("london_crown", "Crown Jewels", "👑", "Cultural object", """
##..##..##
##..##..##
##.####.##
##########
##########
##########
##########
.########.
.########.
..........
"""),
    P("london_corgi", "Corgi", "🐕", "Animal", """
##......##
####..####
##########
#.######.#
##########
###.##.###
##########
.########.
..######..
...####...
"""),
    P("london_bigben", "Big Ben", "🕰", "Landmark", """
.......#.......
......###......
.....#####.....
....#######....
....#######....
...#########...
...#########...
...##.###.##...
...#.#####.#...
...##.###.##...
...#########...
....#######....
....#.#.#.#....
....#######....
....#.#.#.#....
"""),
]

# Starter lines for the postcard composer. Plenty of people freeze at a blank
# box, so the Suggest button drops one of these in to edit. Kept small, warm and
# low-stakes — nothing that assumes anything about the sender or the recipient.
# One letter per city, revealed when that city's postcard is earned. The game's
# prose lives here now rather than on individual discoveries: forty one-liners
# were forty unconnected jokes, five letters can be a single arc.
#
# Empty strings are fine — a city with no letter simply does not offer one.
# Painting direction, one reference per destination. Recorded here so the
# artwork can be regenerated consistently, and so the game knows what kind of
# air each city has.
#
# style : the painter or tradition the postcard imitates
# drift : what moves in the finished picture — petals, motes, dust, rain, none
STYLE = {
    "tokyo":   {"style": "Makoto Shinkai — luminous dusk, lens flare, saturated sky",
                "drift": "petal"},
    "paris":   {"style": "Monet — impressionist broken colour, diffuse gold light",
                "drift": "mote"},
    "rome":    {"style": "Caravaggio — tenebrism, deep shadow, one hard light source",
                "drift": "dust"},
    "newyork": {"style": "Edward Hopper — flat planes of hard light, still and empty",
                "drift": "none"},
    "london":  {"style": "Victorian pale watercolour — soft washes, muted, restrained",
                "drift": "rain"},
}

LETTERS = {
    # Season One: The Last Ones.
    #
    # Five postcards from one stranger to another, each about the last of some
    # thing, with the same line at the end of every one. New York is where the
    # pattern bends — a blossom that falls is gone, a loneliness that is talked
    # out of someone is not. London names what the refrain was doing all along.
    #
    # These are short on purpose. They are meant to be read on the back of the
    # card, in the space where the player will later write their own note.
    "tokyo": {
        "theme": "the last blossom",
        "title": "The Last Blossom",
        "body": "Dear, Unknown,\n\n"
                "There was one blossom left today.\n\n"
                "I thought someone should know.",
    },
    "paris": {
        "theme": "the last croissant",
        "title": "The Last Croissant",
        "body": "Dear, Unknown,\n\n"
                "They sold the last croissant at 7:03.\n"
                "I was there when it happened.\n\n"
                "I thought someone should know.",
    },
    "rome": {
        "theme": "the last coin",
        "title": "The Last Coin",
        "body": "Dear, Unknown,\n\n"
                "An old woman gave me the last coin.\n"
                "She said it wasn't worth anything anymore.\n"
                "I kept it anyway.\n\n"
                "I thought someone should know.",
    },
    "newyork": {
        "theme": "the last lonely person",
        "title": "The Last Lonely Person",
        "body": "Dear, Unknown,\n\n"
                "I met the last lonely person tonight.\n"
                "We talked for an hour.\n"
                "When I left, he wasn't lonely anymore.\n\n"
                "I don't know what that makes me.",
    },
    "london": {
        "theme": "the last postcard",
        "title": "The Last Postcard",
        "body": "Dear, Unknown,\n\n"
                "This is the last postcard.\n"
                "I don't know why I'm sending it.\n"
                "I don't know who you are.\n"
                "I don't even know how I found your address.\n\n"
                "But somehow, every time something became the last of "
                "its kind, I knew I had to write to you.\n\n"
                "Tokyo. Paris. Rome. New York.\n\n"
                "I thought I was recording the end of things.\n"
                "Perhaps I was only making sure someone remembered.\n\n"
                "If you are reading this,\n"
                "then perhaps you are the one I was writing to all along.",
    },
}

GENERIC_NOTES = [
    "Wish you were here.",
    "No news. Just this.",
    "Saved you the good half of the postcard.",
    "Thinking of you from a long way away.",
    "Nothing to report except that it was lovely.",
]

CITY_NOTES = {
    "tokyo": [
        "Ate standing up at a counter built for six. Best meal of the trip.",
        "Got lost in a train station for twenty minutes and enjoyed all of it.",
        "It rained the whole afternoon and somehow that improved things.",
        "Bought coffee from a vending machine. It was genuinely good.",
        "Quieter than you would ever guess from the photos.",
    ],
    "paris": [
        "Sat at a tiny table watching people for an hour. That was the activity.",
        "The bread really is different here. I am sorry to report it.",
        "Walked until my feet hurt, then walked a bit more.",
        "Everything shut for lunch and honestly I respect it.",
        "Found a bench with a good view and stayed there far too long.",
    ],
    "rome": [
        "There is a ruin behind the bus stop and nobody looks at it.",
        "Ate far too much and would do the whole thing again.",
        "The water from the street fountains is freezing and free.",
        "Got lost on purpose. Can recommend.",
        "Everything here is older than it strictly needs to be.",
    ],
    "newyork": [
        "Loud in a way that stops bothering you after about a day.",
        "Walked eleven miles without meaning to.",
        "The pizza argument is real and I have now picked a side.",
        "Looked up constantly for a week. Nobody else does.",
        "Bought something from a cart at midnight. No regrets.",
    ],
    "london": [
        "Rained. Went to a pub instead. The system works.",
        "Sat in a park in the gap between two rain showers.",
        "The tube map is a lie about geography and I love it.",
        "Everyone apologised to me and I apologised straight back.",
        "The museums are free, so I went to three of them.",
    ],
}


# Where each city's pixel pieces stand during the postcard reveal, matched to
# that city's painting: (puzzle_id, centre_x, baseline_y, width) as fractions of
# the frame. This lives beside the content rather than in the renderer because
# it is a property of the artwork, not of the animation.
COMPOSITION = {
    # Tokyo's coordinates are measured off its painting. The rest use an even
    # left / centre / right layout until their artwork exists, but the *choice*
    # of subjects is deliberate everywhere: only scenery goes in a landscape.
    # Food and souvenirs are collected on the card's reverse instead.
    "tokyo": [
        ("tokyo_torii", 0.200, 0.670, 0.190),    # foreground gate, large
        ("tokyo_tower", 0.412, 0.448, 0.090),    # stands in for the far pagoda
        ("tokyo_onigiri", 0.695, 0.752, 0.115),  # the little house on the right
    ],
    "paris": [
        ("paris_arc", 0.205, 0.610, 0.150),
        ("paris_eiffel", 0.480, 0.665, 0.235),
        ("paris_louvre", 0.790, 0.600, 0.140),
    ],
    "rome": [
        ("rome_column", 0.195, 0.605, 0.100),
        ("rome_colosseum", 0.480, 0.660, 0.250),
        ("rome_fountain", 0.790, 0.600, 0.145),
    ],
    "newyork": [
        ("ny_taxi", 0.200, 0.615, 0.145),
        ("ny_liberty", 0.470, 0.665, 0.215),
        ("ny_skyline", 0.780, 0.610, 0.170),
    ],
    "london": [
        ("london_bus", 0.200, 0.615, 0.155),
        ("london_bigben", 0.475, 0.665, 0.200),
        ("london_phonebox", 0.790, 0.605, 0.115),
    ],
}

DEFAULT_COMPOSITION = [(2, 0.215, 0.605, 0.135), (-1, 0.470, 0.660, 0.230),
                       (4, 0.735, 0.605, 0.135)]


def composition_for(city, puzzles):
    slots = COMPOSITION.get(city["id"])
    if slots:
        return [{"id": pid, "x": x, "base": b, "w": w} for pid, x, b, w in slots]
    return [{"id": puzzles[i]["id"], "x": x, "base": b, "w": w}
            for i, x, b, w in DEFAULT_COMPOSITION]


def lonlat(lon, lat):
    """Equirectangular normalised coords, matching the dot map in world_map_view."""
    return [round((lon + 180.0) / 360.0, 4), round((90.0 - lat) / 180.0, 4)]


CITIES = [
    {
        "id": "tokyo", "name": "Tokyo", "country": "Japan", "flag": "🇯🇵",
        "tagline": "Neon evenings and very quiet shrines.",
        "map": lonlat(139.69, 35.69),
        "palette": ["#F6DCE0", "#C25E6B", "#402E33"],
        "puzzles": TOKYO,
    },
    {
        "id": "paris", "name": "Paris", "country": "France", "flag": "🇫🇷",
        "tagline": "Grey stone, gold light, small tables.",
        "map": lonlat(2.35, 48.86),
        "palette": ["#E8E2F2", "#6E63A8", "#2F2A3D"],
        "puzzles": PARIS,
    },
    {
        "id": "rome", "name": "Rome", "country": "Italy", "flag": "🇮🇹",
        "tagline": "Ruins, and people having lunch beside them.",
        "map": lonlat(12.50, 41.90),
        "palette": ["#F7E3CE", "#B96A32", "#3D2E22"],
        "puzzles": ROME,
    },
    {
        "id": "newyork", "name": "New York", "country": "USA", "flag": "🇺🇸",
        "tagline": "Loud, vertical, oddly friendly.",
        "map": lonlat(-74.01, 40.71),
        "palette": ["#DDEAF0", "#2E6E88", "#22333B"],
        "puzzles": NEW_YORK,
    },
    {
        "id": "london", "name": "London", "country": "UK", "flag": "🇬🇧",
        "tagline": "Rain, parks, and a very old river.",
        "map": lonlat(-0.13, 51.51),
        "palette": ["#DEE7DC", "#4C7A57", "#26332A"],
        "puzzles": LONDON,
    },
]


# --------------------------------------------------------------------------
# Nonogram validation
# --------------------------------------------------------------------------

UNKNOWN, EMPTY, FILL = -1, 0, 1


def clues(line):
    out, run = [], 0
    for v in line:
        if v == FILL:
            run += 1
        elif run:
            out.append(run)
            run = 0
    if run:
        out.append(run)
    return out


@lru_cache(maxsize=None)
def placements(length, clue):
    """All ways to lay `clue` runs into a line of `length`, as tuples of 0/1."""
    if not clue:
        return ((EMPTY,) * length,)
    total = sum(clue)
    slack = length - total - (len(clue) - 1)
    if slack < 0:
        return ()
    out = []
    # choose gap sizes g0..gn where g0,gn >= 0 and inner gaps >= 1
    n = len(clue)
    for extra in combinations(range(slack + n), n):
        # standard stars-and-bars: distribute `slack` into n+1 buckets
        pass
    # simpler recursive build
    def build(idx, pos, acc):
        if idx == n:
            out.append(tuple(acc + [EMPTY] * (length - pos)))
            return
        remaining = sum(clue[idx:]) + (n - idx - 1)
        for start in range(pos, length - remaining + 1):
            row = acc + [EMPTY] * (start - pos) + [FILL] * clue[idx]
            nxt = start + clue[idx]
            if idx < n - 1:
                row = row + [EMPTY]
                nxt += 1
            build(idx + 1, nxt, row)

    build(0, 0, [])
    return tuple(out)


def solve_line(length, clue, current):
    """Intersect every placement compatible with `current`. Returns new line or None."""
    fixed = None
    for cand in placements(length, tuple(clue)):
        ok = True
        for c, k in zip(cand, current):
            if k != UNKNOWN and k != c:
                ok = False
                break
        if not ok:
            continue
        if fixed is None:
            fixed = list(cand)
        else:
            for i, v in enumerate(cand):
                if fixed[i] != v:
                    fixed[i] = UNKNOWN
    return fixed


def line_solve(row_clues, col_clues, h, w):
    """Pure line-logic solver. Returns (grid, solved:bool)."""
    grid = [[UNKNOWN] * w for _ in range(h)]
    changed = True
    while changed:
        changed = False
        for r in range(h):
            new = solve_line(w, row_clues[r], grid[r])
            if new is None:
                return None, False
            if new != grid[r]:
                grid[r] = new
                changed = True
        for c in range(w):
            col = [grid[r][c] for r in range(h)]
            new = solve_line(h, col_clues[c], col)
            if new is None:
                return None, False
            if new != col:
                for r in range(h):
                    grid[r][c] = new[r]
                changed = True
    solved = all(UNKNOWN not in row for row in grid)
    return grid, solved


def validate(puzzle):
    art = puzzle["art"]
    h = len(art)
    w = len(art[0])
    errs = []
    for i, row in enumerate(art):
        if len(row) != w:
            errs.append("row %d is %d wide, expected %d" % (i, len(row), w))
        bad = set(row) - {"#", "."}
        if bad:
            errs.append("row %d has bad chars %r" % (i, sorted(bad)))
    if errs:
        return errs, None

    grid = [[FILL if ch == "#" else EMPTY for ch in row] for row in art]
    rc = [clues(row) for row in grid]
    cc = [clues([grid[r][c] for r in range(h)]) for c in range(w)]

    if not any(any(row) for row in grid):
        errs.append("grid is entirely empty")
        return errs, None

    solution, solved = line_solve(rc, cc, h, w)
    if solution is None:
        errs.append("contradictory clues")
    elif not solved:
        unknown = sum(row.count(UNKNOWN) for row in solution)
        errs.append("NOT line-solvable: %d cells need guessing (solution may not be unique)" % unknown)
    elif solution != grid:
        errs.append("solver found a different grid - solution is not unique")
    return errs, {"rows": rc, "cols": cc}


DIFFICULTY = {5: "easy", 10: "medium", 15: "hard"}


def main():
    problems = 0
    out_cities = []
    for city in CITIES:
        out_puzzles = []
        for idx, p in enumerate(city["puzzles"]):
            errs, meta = validate(p)
            size = len(p["art"])
            tag = "%s/%s" % (city["id"], p["id"])
            if errs:
                problems += 1
                print("  FAIL %-28s %s" % (tag, "; ".join(errs)))
            else:
                print("  ok   %-28s %dx%d  %s" % (tag, size, len(p["art"][0]), DIFFICULTY.get(size, "?")))
            out_puzzles.append({
                "id": p["id"],
                "name": p["name"],
                "emoji": p["emoji"],
                "category": p["category"],
                "index": idx,
                "art": p["art"],
            })
        c = dict(city)
        c["puzzles"] = out_puzzles
        c["notes"] = CITY_NOTES.get(city["id"], []) + GENERIC_NOTES
        c["composition"] = composition_for(city, out_puzzles)
        entry = LETTERS.get(city["id"], {})
        c["letter"] = {
            "theme": entry.get("theme", ""),
            "title": entry.get("title", ""),
            "body": entry.get("body", "").strip(),
        }
        c.update(STYLE.get(city["id"], {"style": "", "drift": "mote"}))
        out_cities.append(c)

    if problems:
        print("\n%d puzzle(s) failed validation - not writing %s" % (problems, OUT))
        return 1

    payload = {"version": 1, "cities": out_cities}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
    total = sum(len(c["puzzles"]) for c in out_cities)
    print("\nwrote %s - %d cities, %d puzzles" % (OUT, len(out_cities), total))

    build_web(payload)
    return 0


WEB_TEMPLATE = os.path.join(ROOT, "web", "postcard.template.html")
WEB_OUT = os.path.join(ROOT, "web", "postcard.html")
MARKER = '/*__CITIES__*/ {"cities": []}'


def build_web(payload):
    """Inline the puzzle data so the share page is a single static file."""
    if not os.path.exists(WEB_TEMPLATE):
        return
    with open(WEB_TEMPLATE, encoding="utf-8") as f:
        html = f.read()
    if MARKER not in html:
        print("  WARN %s has no data marker" % WEB_TEMPLATE)
        return
    slim = {"cities": [
        {k: c[k] for k in ("id", "name", "country", "flag", "palette", "puzzles")}
        for c in payload["cities"]
    ]}
    blob = json.dumps(slim, ensure_ascii=False, separators=(",", ":"))
    # </script> inside data would end the tag early; nothing here should contain
    # it, but escape defensively.
    blob = blob.replace("</", "<\\/")
    with open(WEB_OUT, "w", encoding="utf-8") as f:
        f.write(html.replace(MARKER, blob))
    print("wrote %s - %.0f KB" % (WEB_OUT, os.path.getsize(WEB_OUT) / 1024.0))


if __name__ == "__main__":
    sys.exit(main())
