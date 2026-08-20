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

def T(en, zh=""):
    """A translatable string. English is the source; a missing translation falls
    back to it rather than showing a key, so a half-translated build still
    reads."""
    return {"en": en, "zh_CN": zh or en}


# Discovery names, in the order the cities list them.
ZH_NAMES = {
    "tokyo_fuji": "富士山", "tokyo_lantern": "纸灯笼", "tokyo_torii": "鸟居",
    "tokyo_ramen": "拉面", "tokyo_onigiri": "饭团", "tokyo_shinkansen": "新干线",
    "tokyo_sakura": "樱花", "tokyo_tower": "东京塔",
    "paris_wine": "一杯红酒", "paris_brie": "布里奶酪", "paris_croissant": "可颂",
    "paris_macaron": "马卡龙", "paris_cafe": "欧蕾咖啡", "paris_arc": "凯旋门",
    "paris_louvre": "玻璃金字塔", "paris_eiffel": "埃菲尔铁塔",
    "rome_gelato": "意式冰淇淋", "rome_column": "罗马柱", "rome_pizza": "切角披萨",
    "rome_pasta": "黑椒芝士面", "rome_vespa": "韦士柏", "rome_fountain": "喷泉",
    "rome_amphora": "双耳陶罐", "rome_colosseum": "斗兽场",
    "ny_apple": "大苹果", "ny_walkup": "无电梯公寓", "ny_taxi": "黄色出租车",
    "ny_skyline": "天际线", "ny_traffic": "红绿灯", "ny_bagel": "贝果",
    "ny_hotdog": "街头热狗", "ny_liberty": "自由女神",
    "london_tea": "一杯茶", "london_rain": "阵雨", "london_bus": "双层巴士",
    "london_phonebox": "电话亭", "london_umbrella": "雨伞",
    "london_crown": "王冠", "london_corgi": "柯基", "london_bigben": "大本钟",
}

ZH_CATEGORIES = {
    "Nature": "自然", "Cultural object": "文化", "Architecture": "建筑",
    "Food": "食物", "Transportation": "交通", "Everyday life": "日常",
    "Landmark": "地标", "Animal": "动物",
}

ZH_CITIES = {
    "tokyo": ("东京", "日本"), "paris": ("巴黎", "法国"),
    "rome": ("罗马", "意大利"), "newyork": ("纽约", "美国"),
    "london": ("伦敦", "英国"),
    "kyoto": ("京都", "日本"), "sanfrancisco": ("旧金山", "美国"),
    "istanbul": ("伊斯坦布尔", "土耳其"), "reykjavik": ("雷克雅未克", "冰岛"),
    "bermuda": ("百慕大", "北大西洋"),
}


def P(pid, name, emoji, category, art):
    """One discovery.

    `emoji` is kept in the source as a note to whoever is authoring the art —
    it never reaches the game. A row of coloured pictograms made the interface
    read as a toy, which is the wrong register for a game about letters.
    """
    return {
        "id": pid,
        "name": T(name, ZH_NAMES.get(pid, "")),
        "category": T(category, ZH_CATEGORIES.get(category, "")),
        "art": [row for row in art.strip().splitlines()],
    }


TOKYO = [
    # Five, not eight. The letter is the payoff for finishing a destination, and
    # eight grids is a long time to wait for four lines of it.
    #
    # Sizes rise by cell count, not by squaring off: the aspect follows the
    # subject, so a gate is wide and a tower is tall and two puzzles of the same
    # difficulty feel nothing alike.
    # Deliberately small, and deliberately the simplest shape in the game: this
    # exact grid comes back as the first colour puzzle of Season Two, in Kyoto,
    # in pink. Keeping it tiny is what makes that callback teachable rather than
    # punishing — the player spends nothing on the shape and everything on the
    # new rule.
    P("tokyo_sakura", "Cherry Blossom", "🌸", "Nature", """
.#.#.
#####
.###.
#####
.#.#.
"""),
    P("tokyo_onigiri", "Onigiri", "🍙", "Food", """
...##...
..####..
..####..
.######.
.######.
########
##....##
########
"""),
    # Third slot, and the only asymmetric grid in the city. Four symmetric
    # puzzles in a row and solving turns mechanical — you deduce the left half
    # and mirror it. One that refuses to mirror makes the player look again.
    # Every city gets exactly one, here.
    P("tokyo_shinkansen", "Shinkansen", "🚄", "Transportation", """
.......#######
....##########
..############
##############
##############
...##.....##..
"""),
    P("tokyo_torii", "Torii Gate", "⛩️", "Architecture", """
############
############
..########..
...#....#...
...#....#...
...#....#...
...#....#...
..###..###..
"""),
    P("tokyo_tower", "Tokyo Tower", "🗼", "Landmark", """
...##...
...##...
..####..
..####..
..#..#..
..#..#..
.##..##.
.##..##.
.#....#.
.#....#.
##....##
##....##
########
########
"""),
]

PARIS = [
    P("paris_macaron", "Macaron", "🍬", "Food", """
..####..
.######.
########
.######.
.######.
########
.######.
..####..
"""),
    # Paris's asymmetric one. A croissant is a crescent that has been rolled
    # from one end, so drawing it symmetrically makes it a bagel.
    P("paris_croissant", "Croissant", "🥐", "Food", """
.....####....
...#######...
..###...###..
.###.....##..
.##.......#..
.##..........
..#..........
"""),
    P("paris_arc", "Arc de Triomphe", "🇫🇷", "Landmark", """
##########
##########
##.#..#.##
##########
###.##.###
###.##.###
###.##.###
###.##.###
###.##.###
##########
"""),
    P("paris_louvre", "Glass Pyramid", "🔺", "Architecture", """
.....##.....
....####....
....####....
...######...
...######...
..########..
..########..
.##########.
############
"""),
    P("paris_eiffel", "Eiffel Tower", "🗼", "Landmark", """
....##....
....##....
...####...
...####...
..######..
..#....#..
..#....#..
.##....##.
.#......#.
.#......#.
##......##
#........#
#........#
##########
##########
"""),
]

ROME = [
    # The coin the old woman gives away in Rome's letter. It had no puzzle at
    # all until now — the one object the story names outright was the one thing
    # you could not find in the journal.
    P("rome_coin", "The Last Coin", "🪙", "Cultural object", """
..######..
.########.
##.####.##
##########
###....###
##.####.##
##.####.##
##########
.########.
..######..
"""),
    P("rome_column", "Roman Column", "🏛️", "Architecture", """
#######
#######
.#####.
..###..
..###..
..###..
..###..
..###..
..###..
..###..
..###..
..###..
.#####.
#######
#######
"""),
    # Rome's asymmetric one: a scooter points somewhere.
    P("rome_vespa", "Vespa", "🛵", "Transportation", """
..........###
.........####
....######..#
..#########.#
.###########.
.###########.
.####...####.
.###.....###.
..#.......#..
"""),
    P("rome_fountain", "Fountain", "⛲", "Landmark", """
....####....
...######...
....####....
.....##.....
.....##.....
....####....
...######...
..########..
.##########.
############
############
"""),
    P("rome_colosseum", "Colosseum", "🏟️", "Landmark", """
...#########...
..###########..
.#############.
###############
##.##.###.##.##
###############
##.##.###.##.##
###############
##.##.###.##.##
###############
###############
###############
###############
"""),
]

NEW_YORK = [
    # One figure, not two. New York's letter is about the last lonely person
    # M ever met, and a second silhouette would answer the question the letter
    # is asking.
    P("ny_figure", "Someone", "🧍", "Everyday life", """
...####.
..######
..######
...####.
....##..
..######
.#.####.
.#.####.
...####.
...####.
...####.
...##.#.
...##.#.
...##.#.
..###.##
"""),
    P("ny_bagel", "Bagel", "🥯", "Food", """
...######...
..########..
.##########.
############
####....####
###......###
###......###
####....####
############
.##########.
..########..
"""),
    # New York's asymmetric one: a cab is pointed somewhere, and in this city
    # that is the whole idea.
    P("ny_taxi", "Yellow Cab", "🚕", "Transportation", """
.....######....
....########...
...##########..
.##############
###############
###############
##.##.###.##.##
###############
.###.......###.
..#.........#..
"""),
    P("ny_skyline", "Skyline", "🌆", "Landmark", """
.......#.......
.......#.......
......###......
..#...###...##.
..#...###...##.
.###..###..####
.###..###..####
####.#####.####
###############
###############
###############
"""),
    P("ny_liberty", "Statue of Liberty", "🗽", "Landmark", """
...#.#.#....
...#####....
....###.....
....###.....
..#.###.....
..#.###.....
..#.####....
..#.#####...
....#####...
....#####...
...#######..
...#######..
..#########.
..#########.
.###########
.###########
############
############
############
############
"""),
]

LONDON = [
    P("london_phonebox", "Phone Box", "☎️", "Architecture", """
##########
##########
#.######.#
#.######.#
#.######.#
#.######.#
##########
#.##..##.#
#.##..##.#
#.##..##.#
##########
#.######.#
#.######.#
#.######.#
##########
##########
##########
##########
"""),
    P("london_umbrella", "Umbrella", "☔", "Everyday life", """
.....##......
..#########..
.###########.
#############
.....##......
.....##......
.....##......
.....##......
.....##......
.....##......
.....##......
....##.......
.####........
.###.........
"""),
    # London's asymmetric one. A bus has a front and a back.
    P("london_bus", "Double-Decker", "🚌", "Transportation", """
..#############
.##############
.#.##.##.##.###
.##############
.##############
.#.##.##.##.#.#
.##############
###############
###############
##.#########.##
###.#######.###
.##.........##.
..#.........#..
"""),
    # The last picture in the season, and the thing the last letter is about.
    P("london_postcard", "A Postcard", "✉️", "Cultural object", """
###############
###############
##...........##
##.#####.###.##
##.#####.....##
##.#####.###.##
##.......###.##
##.#####.....##
##.#####.###.##
##.......###.##
##.#####.....##
##.#####.###.##
##...........##
###############
###############
"""),
    P("london_bigben", "Big Ben", "🕰️", "Landmark", """
.......#.......
.......#.......
......###......
.....#####.....
....#######....
...#########...
...#########...
..###########..
..###########..
..##.......##..
..##.#####.##..
..##.##.##.##..
..##.##.##.##..
..##.#####.##..
..##.......##..
..###########..
..###########..
.#############.
###############
###############
"""),
]


def lonlat(lon, lat):
    """Equirectangular normalised coords, matching the dot map in world_map_view."""
    return [round((lon + 180.0) / 360.0, 4), round((90.0 - lat) / 180.0, 4)]


# ---------------------------------------------------------------------------
# Season Two: The Color Doesn't Exist
#
# The destinations are settled; the discoveries are not. The puzzle design is
# being reworked, so these are deliberately empty — a destination with no
# puzzles yet is a state the game handles rather than a broken one, and it
# shows on the map as somewhere still being written.

KYOTO = []
SAN_FRANCISCO = []
ISTANBUL = []
REYKJAVIK = []
BERMUDA = []

CITIES = [
    {
        "id": "tokyo", "name": "Tokyo", "country": "Japan",
        "map": lonlat(139.69, 35.69),
        "palette": ["#F6DCE0", "#C25E6B", "#402E33"],
        "puzzles": TOKYO,
    },
    {
        "id": "paris", "name": "Paris", "country": "France",
        "map": lonlat(2.35, 48.86),
        "palette": ["#E8E2F2", "#6E63A8", "#2F2A3D"],
        "puzzles": PARIS,
    },
    {
        "id": "rome", "name": "Rome", "country": "Italy",
        "map": lonlat(12.50, 41.90),
        "palette": ["#F7E3CE", "#B96A32", "#3D2E22"],
        "puzzles": ROME,
    },
    {
        "id": "newyork", "name": "New York", "country": "USA",
        "map": lonlat(-74.01, 40.71),
        "palette": ["#DDEAF0", "#2E6E88", "#22333B"],
        "puzzles": NEW_YORK,
    },
    {
        "id": "london", "name": "London", "country": "UK",
        "map": lonlat(-0.13, 51.51),
        "palette": ["#DEE7DC", "#4C7A57", "#26332A"],
        "puzzles": LONDON,
    },
    # Season Two. Each palette is built around a colour the place is known for
    # and nobody can quite reproduce: temple moss, the orange of a bridge seen
    # through fog, Iznik turquoise, an aurora, pink sand.
    {
        "id": "kyoto", "name": "Kyoto", "country": "Japan",
        "map": lonlat(135.77, 35.01),
        "palette": ["#E3E8DA", "#5F7A4C", "#2A3325"],
        "puzzles": KYOTO,
    },
    {
        "id": "sanfrancisco", "name": "San Francisco", "country": "USA",
        "map": lonlat(-122.42, 37.77),
        "palette": ["#F2E4DA", "#C1552E", "#3A2A24"],
        "puzzles": SAN_FRANCISCO,
    },
    {
        "id": "istanbul", "name": "Istanbul", "country": "Turkiye",
        "map": lonlat(28.98, 41.01),
        "palette": ["#DCEAEA", "#2F7E82", "#22343A"],
        "puzzles": ISTANBUL,
    },
    {
        "id": "reykjavik", "name": "Reykjavik", "country": "Iceland",
        "map": lonlat(-21.94, 64.15),
        "palette": ["#DEE9E6", "#3E8A73", "#20302C"],
        "puzzles": REYKJAVIK,
    },
    {
        "id": "bermuda", "name": "Bermuda", "country": "North Atlantic",
        "map": lonlat(-64.78, 32.29),
        "palette": ["#F6E1E0", "#C4707B", "#3A2A2E"],
        "puzzles": BERMUDA,
    },
]



# Suggestion lines offered when composing a postcard, because plenty of people
# freeze at an empty message box. City-specific ones first, then the ones that
# work anywhere.
CITY_NOTES = {
    'tokyo': [
        'Ate standing up at a counter built for six. Best meal of the trip.',
        'Got lost in a train station for twenty minutes and enjoyed all of it.',
        'It rained the whole afternoon and somehow that improved things.',
        'Bought coffee from a vending machine. It was genuinely good.',
        'Quieter than you would ever guess from the photos.',
    ],
    'paris': [
        'Sat at a tiny table watching people for an hour. That was the activity.',
        'The bread really is different here. I am sorry to report it.',
        'Walked until my feet hurt, then walked a bit more.',
        'Everything shut for lunch and honestly I respect it.',
        'Found a bench with a good view and stayed there far too long.',
    ],
    'rome': [
        'There is a ruin behind the bus stop and nobody looks at it.',
        'Ate far too much and would do the whole thing again.',
        'The water from the street fountains is freezing and free.',
        'Got lost on purpose. Can recommend.',
        'Everything here is older than it strictly needs to be.',
    ],
    'newyork': [
        'Loud in a way that stops bothering you after about a day.',
        'Walked eleven miles without meaning to.',
        'The pizza argument is real and I have now picked a side.',
        'Looked up constantly for a week. Nobody else does.',
        'Bought something from a cart at midnight. No regrets.',
    ],
    'london': [
        'Rained. Went to a pub instead. The system works.',
        'Sat in a park in the gap between two rain showers.',
        'The tube map is a lie about geography and I love it.',
        'Everyone apologised to me and I apologised straight back.',
        'The museums are free, so I went to three of them.',
    ],
}

GENERIC_NOTES = [
    'Wish you were here.',
    'No news. Just this.',
    'Saved you the good half of the postcard.',
    'Thinking of you from a long way away.',
    'Nothing to report except that it was lovely.',
]

# The painter each postcard is generated against, and what drifts through its
# sky. Both reach the game as plain strings; the style line is a prompt for
# whoever renders the artwork, not something the engine reads.
STYLE = {
    'tokyo': {"style": 'Makoto Shinkai — luminous dusk, lens flare, saturated sky',
     "drift": 'petal'},
    'paris': {"style": 'Monet — impressionist broken colour, diffuse gold light',
     "drift": 'mote'},
    'rome': {"style": 'Caravaggio — tenebrism, deep shadow, one hard light source',
     "drift": 'dust'},
    'newyork': {"style": 'Edward Hopper — flat planes of hard light, still and empty',
     "drift": 'none'},
    'london': {"style": 'Victorian pale watercolour — soft washes, muted, restrained',
     "drift": 'rain'},
    'kyoto': {"style": 'Hasui Kawase — shin-hanga, still water, lantern light',
     "drift": 'petal'},
    'sanfrancisco': {"style": 'Richard Diebenkorn — flat bay light, hard-edged colour fields',
     "drift": 'mote'},
    'istanbul': {"style": 'Iznik ceramic — turquoise and cobalt on white, patterned',
     "drift": 'dust'},
    'reykjavik': {"style": 'Northern night — low sun, long shadow, aurora over snow',
     "drift": 'none'},
    'bermuda': {"style": 'Winslow Homer — watercolour, sunlight through shallow water',
     "drift": 'mote'},
}

# When M posted each card, which is not the order they reach the player. The
# postmark is the only place this shows, deliberately small: it is meant to be
# noticed on a second reading, not announced on the first.
SENT = {
    'tokyo': '27 JUN 2019',
    'paris': '30 NOV 2019',
    'rome': '03 APR 2019',
    'newyork': '19 AUG 2019',
    'london': '11 FEB 2019',
    'kyoto': '14 MAY 2020',
    'sanfrancisco': '18 DEC 2020',
    'istanbul': '07 JAN 2020',
    'reykjavik': '02 SEP 2020',
    'bermuda': '22 MAR 2020',
}

# Which three discoveries the postcard's mosaic resolves out of, and where each
# one sits on the finished painting. Measured by hand against the artwork.
COMPOSITION = {
    'tokyo': [
        ('tokyo_torii', 0.2, 0.67, 0.19),
        ('tokyo_tower', 0.412, 0.448, 0.09),
        ('tokyo_onigiri', 0.695, 0.752, 0.115),
    ],
    'paris': [
        ('paris_arc', 0.174, 0.6, 0.099),
        ('paris_eiffel', 0.573, 0.6, 0.104),
        ('paris_louvre', 0.63, 0.655, 0.15),
    ],
    'rome': [
        ('rome_column', 0.075, 0.76, 0.105),
        ('rome_colosseum', 0.455, 0.6, 0.3),
        ('rome_fountain', 0.905, 0.745, 0.13),
    ],
    'newyork': [
        ('ny_taxi', 0.313, 0.84, 0.156),
        ('ny_liberty', 0.693, 0.515, 0.09),
        ('ny_skyline', 0.37, 0.475, 0.3),
    ],
    'london': [
        ('london_phonebox', 0.276, 0.792, 0.073),
        ('london_bigben', 0.434, 0.612, 0.068),
        ('london_bus', 0.617, 0.702, 0.214),
    ],
}

DEFAULT_COMPOSITION = [(2, 0.215, 0.605, 0.135), (-1, 0.470, 0.660, 0.230),
                       (4, 0.735, 0.605, 0.135)]


def composition_for(city, puzzles):
    """Which discoveries the postcard dissolves out of, and where they sit.

    A city being written still has fewer than three puzzles, and the default
    layout asks for three by index. Take the slots the city can actually fill
    rather than failing the build — the composition is a nicety, and the point
    of a skeleton is that it runs before it is finished.
    """
    slots = COMPOSITION.get(city["id"])
    if slots:
        return [{"id": pid, "x": x, "base": b, "w": w} for pid, x, b, w in slots]
    out = []
    for i, x, b, w in DEFAULT_COMPOSITION:
        if not (-len(puzzles) <= i < len(puzzles)):
            continue
        out.append({"id": puzzles[i]["id"], "x": x, "base": b, "w": w})
    return out


LETTERS = {
    'tokyo': {
        "theme": 'the last blossom',
        "title": 'The Last Blossom',
        "body": 'Dear, Unknown,\n\nThere was one blossom left today.\n\nI thought someone should know.\n\n— M',
        "body_zh": '亲爱的陌生人：\n\n今天只剩下最后一朵樱花了。\n\n我想，总该有人知道这件事。\n\n—— M',
    },
    'paris': {
        "theme": 'the last croissant',
        "title": 'The Last Croissant',
        "body": 'Dear, Unknown,\n\nThey sold the last croissant at 7:03.\nI was there when it happened.\n\nI thought someone should know.\n\n— M',
        "body_zh": '亲爱的陌生人：\n\n七点零三分，最后一个可颂被买走了。\n那一刻我正好在场。\n\n我想，总该有人知道这件事。\n\n—— M',
    },
    'rome': {
        "theme": 'the last coin',
        "title": 'The Last Coin',
        "body": "Dear, Unknown,\n\nAn old woman gave me the last coin.\nShe said it wasn't worth anything anymore.\nI kept it anyway.\n\nI thought someone should know.\n\n— M",
        "body_zh": '亲爱的陌生人：\n\n一位老太太把最后一枚硬币给了我。\n她说这枚硬币已经不值钱了。\n我还是留下了它。\n\n我想，总该有人知道这件事。\n\n—— M',
    },
    'newyork': {
        "theme": 'the last lonely person',
        "title": 'The Last Lonely Person',
        "body": "Dear, Unknown,\n\nI met the last lonely person tonight.\nWe talked for an hour.\nWhen I left, he wasn't lonely anymore.\n\nI don't know what that makes me.\n\n— M",
        "body_zh": '亲爱的陌生人：\n\n今晚我遇见了最后一个孤独的人。\n我们聊了一个小时。\n我离开的时候，他已经不孤独了。\n\n我不知道这让我成了什么。\n\n—— M',
    },
    'london': {
        "theme": 'the last postcard',
        "title": 'The Last Postcard',
        "body": "Dear, Unknown,\n\nThis is the last postcard.\nI don't know why I'm sending it.\nI don't know who you are.\nI don't even know how I found your address.\n\nBut somehow, every time something became the last of its kind, I knew I had to write to you.\n\nTokyo. Paris. Rome. New York.\n\nI thought I was recording the end of things.\nPerhaps I was only making sure someone remembered.\n\nIf you are reading this,\nthen perhaps you are the one I was writing to all along.\n\n— M",
        "body_zh": '亲爱的陌生人：\n\n这是最后一张明信片。\n我不知道自己为什么要寄。\n我不知道你是谁。\n我甚至不知道我是怎么找到你的地址的。\n\n可是每当有什么东西成为它那一类里的最后一个，\n我就知道我必须写信给你。\n\n东京。巴黎。罗马。纽约。\n\n我以为我在记录事物的终结。\n也许我只是想确认，还有人记得。\n\n如果你正在读这封信，\n那么也许，你就是我一直在写的那个人。\n\n—— M',
    },
}

SEASONS = [
    {
        "id": 's1',
        "number": 1,
        "title": 'The Last Ones',
        "cities": ['tokyo', 'paris', 'rome', 'newyork', 'london'],
        "opening": {
            "body": "Dear, Unknown,\n\nI don't know where you are anymore.\n\nSo I sent one to every place\nI thought you might be.\n\n— M",
            "body_zh": '亲爱的陌生人：\n\n我已经不知道你在哪里了。\n\n所以我往每一个\n你可能在的地方都寄了一张。\n\n—— M',
        },
    },
    {
        "id": 's2',
        "number": 2,
        "title": "The Color Doesn't Exist",
        "cities": ['kyoto', 'sanfrancisco', 'istanbul', 'reykjavik', 'bermuda'],
        # Only the first season opens with a letter.
    },
]


# Cell states for the solver. EMPTY must be falsy: the "grid is entirely empty"
# check relies on it.
EMPTY = 0
FILL = 1
UNKNOWN = 2

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


# Difficulty by area rather than by side, now that grids are not square. The
# thresholds are where the solve time noticeably steps up, not round numbers.
def difficulty_of(width, height):
    cells = width * height
    if cells <= 36:
        return "easy"
    if cells <= 120:
        return "medium"
    if cells <= 225:
        return "hard"
    return "long"


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
                w = len(p["art"][0])
                print("  ok   %-28s %2dx%-2d %4d  %s"
                      % (tag, w, size, w * size, difficulty_of(w, size)))
            out_puzzles.append({
                "id": p["id"],
                "name": p["name"],
                "category": p["category"],
                "index": idx,
                "art": p["art"],
            })
        c = dict(city)
        zh_name, zh_country = ZH_CITIES.get(city["id"], ("", ""))
        c["name"] = T(city["name"], zh_name)
        c["country"] = T(city["country"], zh_country)
        c["puzzles"] = out_puzzles
        c["notes"] = CITY_NOTES.get(city["id"], []) + GENERIC_NOTES
        c["composition"] = composition_for(city, out_puzzles)
        entry = LETTERS.get(city["id"], {})
        c["letter"] = {
            "theme": entry.get("theme", ""),
            "title": T(entry.get("title", "")),
            "body": T(entry.get("body", "").strip(),
                      entry.get("body_zh", "").strip()),
        }
        c.update(STYLE.get(city["id"], {"style": "", "drift": "mote"}))
        c["sent"] = SENT.get(city["id"], "")
        out_cities.append(c)

    if problems:
        print("\n%d puzzle(s) failed validation - not writing %s" % (problems, OUT))
        return 1

    by_id = {c["id"]: c for c in out_cities}
    for season in SEASONS:
        missing = [c for c in season["cities"] if c not in by_id]
        if missing:
            print("  FAIL season %s lists unknown cities: %s"
                  % (season["id"], ", ".join(missing)))
            return 1
        for i, cid in enumerate(season["cities"]):
            by_id[cid]["season"] = season["id"]
            by_id[cid]["season_index"] = i

    out_seasons = []
    for season in SEASONS:
        sc = dict(season)
        sc["title"] = T(season["title"])
        # Only the first season opens with a letter. The ones after it are
        # already under way when the player arrives, so a season without an
        # "opening" key is expected, not an omission to be filled in.
        opening = season.get("opening")
        if opening:
            sc["opening"] = {"body": T(opening["body"],
                                       opening.get("body_zh", ""))}
        else:
            sc.pop("opening", None)
        out_seasons.append(sc)

    payload = {"version": 1, "seasons": out_seasons, "cities": out_cities}
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
        {k: c[k] for k in ("id", "name", "country", "palette", "puzzles")}
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
