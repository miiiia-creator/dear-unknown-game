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
    "rome_pasta": "黑椒芝士面", "rome_fountain": "喷泉",
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


def P(pid, name, emoji, category, art, colours=None):
    """One discovery.

    `emoji` is kept in the source as a note to whoever is authoring the art —
    it never reaches the game. A row of coloured pictograms made the interface
    read as a toy, which is the wrong register for a game about letters.
    """
    return {
        "id": pid,
        # Inks this grid uses, in order. Empty means the one ink the game has
        # always drawn with, so every black-and-white puzzle stays untouched.
        "palette": colours or [],
        "name": T(name, ZH_NAMES.get(pid, "")),
        "category": T(category, ZH_CATEGORIES.get(category, "")),
        "art": [row for row in art.strip().splitlines()],
    }


TOKYO = [
    # Three, not five. Tokyo is where the game teaches itself, and each grid
    # here exists to introduce exactly one idea.
    #
    # The pond first: an ellipse whose middle three rows are a plain 5, so the
    # first thing a player ever deduces is "the number is how many in a row",
    # with nothing else in the way.
    P("tokyo_pond", "The Pond", "🌊", "Nature", """
.###.
#####
#####
#####
.###.
"""),
    # Then the blossom, the first grid where a line carries two numbers — the
    # idea the pond deliberately avoided. Same five cells across, so the only
    # new thing is the clue.
    P("tokyo_sakura", "Cherry Blossom", "🌸", "Nature", """
.#.#.
#####
.###.
#####
.#.#.
"""),
    # Square, like the two before it. Three square grids in a row and a player
    # stops wondering what shape the next one is — which is worth setting up,
    # because it is not true and finding that out should cost something.
    P("tokyo_torii", "Torii Gate", "\u26e9", "Architecture", """
##########
##########
.########.
..######..
..#....#..
..#....#..
..#....#..
..#....#..
..#....#..
.###..###.
""")
]

PARIS = [
    # The blackboard in the painting says le dernier croissant aujourd'hui, so
    # the smallest grid in the city is the thing the letter is about.
    P("paris_croissant", "Croissant", "\U0001f950", "Food", """
.##....##.
##########
.########.
..######..
...####...
"""),
    # Paris's asymmetric one. A cup has a handle and the handle is on one side;
    # nothing else on this card refuses to mirror.
    P("paris_cafe", "Caf\u00e9 Cr\u00e8me", "\u2615", "Food", """
########..
########..
######.##.
######..#.
######..#.
######.##.
########..
.######...
..####....
"""),
    P("paris_eiffel", "Eiffel Tower", "\U0001f5fc", "Landmark", """
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
    # Two, and gentler than Paris was. The coin is where overlap reasoning is
    # taught: a run of eight in a line of ten fixes six cells wherever it sits,
    # and nothing in the first six grids needed that.
    P("rome_coin", "The Last Coin", "\U0001fa99", "Cultural object", """
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
    P("rome_fountain", "Fountain", "\u26f2", "Landmark", """
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
]

NEW_YORK = [
    # One figure, not two. New York's letter is about the last lonely person M
    # ever met, and a second silhouette would answer the question the letter is
    # asking. It is also the sparsest grid so far: single cells with no runs to
    # overlap, which cannot be finished without marking the blanks.
    P("ny_figure", "Someone", "\U0001f9cd", "Everyday life", """
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
    P("ny_taxi", "Yellow Cab", "\U0001f695", "Transportation", """
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
]

LONDON = [
    # Two grids the same size, which is the point. The first is large and gives
    # itself up quickly — solid tower, heavy clues — so the player finishes it
    # thinking they have the measure of a fifteen by twenty.
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
    # The same size again, and it inverts: what gets filled is the ground, not
    # the drawing. Every grid up to here has been a dark shape on empty paper,
    # so the clues read as enormous and the player fills almost the whole board
    # before the blank in the middle resolves into the thing they have been
    # receiving all season.
    #
    # It inverts twice, in fact. Inside the blank card the stamp and the two
    # written lines are filled again — dark on light, inside light on dark.
    #
    # The letter it arrives with is about a sky that never changes and
    # afternoons that feel like evenings. A picture made of absence is the one
    # this city should end on.
    P("london_postcard", "The Last Postcard", "\u2709", "Cultural object", """
###############
###############
###############
###############
###############
###############
###############
##...........##
##.......###.##
##.......###.##
##.......###.##
##...........##
##.######....##
##...........##
##.######....##
##...........##
###############
###############
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

# Kyoto's palette: the pink the letter comes looking for, and the black that
# replaced it. Two inks, because the first colour city has to teach the rule —
# same colour needs a gap, different colours may touch — and the shapes should
# cost the player nothing while they learn it.
# Season Two brings colour back one ink at a time: Kyoto has a single one, and
# it is the pink the letter goes looking for and does not find. By Bermuda
# there are more than anyone can count. The season is called The Color Doesn't
# Exist, and the count itself is the argument.
KYOTO_INKS = ["#E8A0B4"]

KYOTO = [
    # The same five cells as Tokyo's very first puzzle, one season later. The
    # player has solved this shape before, so everything they spend goes on the
    # new rule rather than on working out what they are drawing — and the shape
    # arrives in a colour the letter says is gone.
    P("kyoto_sakura", "Cherry Blossom, in Colour", "\U0001f338", "Nature", """
.#.#.
#####
.###.
#####
.#.#.
""", KYOTO_INKS),
    # Even the little Hello Kitty in the shop window is black now, says the
    # letter. Here she is in pink, which is either what M remembers or what M
    # is imagining — the letter does not say which and neither does this.
    P("kyoto_kitty", "Black This Year", "\U0001f380", "Everyday life", """
.##....##.
####..####
##########
##.####.##
##########
##.#..#.##
##########
.########.
..######..
""", KYOTO_INKS),
]

# Crust and crumb. Two inks, and the first grid in the game where a colour
# means a material rather than an outline.
SF_INKS = ["#8A5A32", "#E0A94A"]

SAN_FRANCISCO = [
    # M asks for a croissant and is told they do not make those. It is drawn
    # large and alone here, taking most of the card — the thing the city has
    # stopped having, given the space it used to occupy.
    P("sf_croissant", "They Don't Make Those", "\U0001f950", "Food", """
.11....11.
1111..1111
1122222211
.22222222.
..222222..
""", SF_INKS),
    # And what it was replaced by, several times over at different sizes. The
    # repetition is the point: everyone here prefers sourdough now.
    P("sf_sourdough", "A Sourdough City", "\U0001f35e", "Food", """
..1111....11..
.112211..1221.
.222222..2222.
..2222....22..
....111111....
...11222211...
...22222222...
....222222....
""", SF_INKS),
]
ISTANBUL = []
REYKJAVIK = []
BERMUDA = []

CITIES = [
    {
        "id": "tokyo", "name": "Tokyo", "country": "Japan",
        "map": lonlat(139.69, 35.69),
        "palette": ["#EDECE9", "#6B6B67", "#2A2A27"],
        "puzzles": TOKYO,
    },
    {
        "id": "paris", "name": "Paris", "country": "France",
        "map": lonlat(2.35, 48.86),
        "palette": ["#ECEBE9", "#73736F", "#2C2C29"],
        "puzzles": PARIS,
    },
    {
        "id": "rome", "name": "Rome", "country": "Italy",
        "map": lonlat(12.50, 41.90),
        "palette": ["#EEECE8", "#6F6C66", "#2C2A26"],
        "puzzles": ROME,
    },
    {
        "id": "newyork", "name": "New York", "country": "USA",
        "map": lonlat(-74.01, 40.71),
        "palette": ["#EBEBEA", "#68696A", "#282929"],
        "puzzles": NEW_YORK,
    },
    {
        "id": "london", "name": "London", "country": "UK",
        "map": lonlat(-0.13, 51.51),
        "palette": ["#EAEBEA", "#6C7070", "#292B2B"],
        "puzzles": LONDON,
    },
    # Season Two. Each palette is built around a colour the place is known for
    # and nobody can quite reproduce: temple moss, the orange of a bridge seen
    # through fog, Iznik turquoise, an aurora, pink sand.
    {
        "id": "kyoto", "name": "Kyoto", "country": "Japan",
        "map": lonlat(135.77, 35.01),
        "palette": ["#F6DCE4", "#B4708A", "#3A2A32"],
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
    ],
    'newyork': [
    ],
    'london': [
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
    'tokyo': '08 APR 2019',
    'paris': '17 MAY 2019',
    'rome': '03 JUN 2019',
    'newyork': '21 OCT 2019',
    'london': '12 NOV 2019',
}

# Which three discoveries the postcard's mosaic resolves out of, and where each
# one sits on the finished painting. Measured by hand against the artwork.
COMPOSITION = {
    'tokyo': [
        ('tokyo_sakura', 0.225, 0.620, 0.24),
        ('tokyo_torii', 0.735, 0.655, 0.185),
        ('tokyo_pond', 0.480, 0.955, 0.58),
    ],
    'paris': [
        ('paris_eiffel', 0.240, 0.335, 0.135),
        ('paris_cafe', 0.255, 0.800, 0.360),
        ('paris_croissant', 0.680, 0.835, 0.420),
    ],
    '_paris_old': [
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


# The five letters. Written, not translated — the Chinese versions are their
# own drafts rather than line-for-line renderings, and are added back one at a
# time as they are written.
LETTERS = {
    'tokyo': {
        "theme": 'waiting',
        "title": 'The Last Cherry Blossom',
        "body": 'Dear, Unknown,\nMost of the trees were already bare.\nThen I saw one.\nA single cherry blossom above the pond.\nIt was the most beautiful shade of pink.\nI wish you could have seen it.\n— M',
        "title_zh": '最后一朵樱花',
        "body_zh": '亲爱的陌生人：\n树差不多都空了。\n然后我看见一朵。\n池塘上方，只有那一朵樱花。\n那是我见过最好看的粉色。\n真希望你也能看见。\n—— M',
    },
    'bermuda': {
        "theme": 'kindness',
        "title": 'Just in Case',
        "title_zh": '以防万一',
        "body": "Dear, Unknown,\nI came to Bermuda today.\nSomeone told me about the Triangle.\nShips disappear. Planes disappear.\nWe always seem to find a reason.\nThings have been changing lately.\nMaybe I'm the only one who notices.\nI wrote some of them down.\nI'm glad I did.\nI don't know why.\nSo I'll keep writing.\nJust in case.\n— M",
        "body_zh": '亲爱的陌生人：\n今天我到了百慕大。\n有人跟我说起那个三角。\n船会消失。飞机会消失。\n我们好像总能找到一个解释。\n最近有些东西在变。\n也许只有我一个人注意到。\n我把其中一些写了下来。\n我很庆幸我写了。\n我不知道为什么。\n所以我会继续写。\n以防万一。\n—— M',
    },
    'paris': {
        "theme": 'missing it',
        "title": 'The Last Croissant',
        "body": "Dear, Unknown,\nI found a little boulangerie this morning.\nThe baker said it was the last one.\nIt was still warm,\nso I ate it by the window\nwith a coffee and the sound of bicycles outside.\nI thought about saving half for you.\nI didn't.\nI'm sorry.\n— M",
        "title_zh": '最后一只可颂',
        "body_zh": '亲爱的陌生人：\n今天早上我找到一家很小的面包店。\n面包师说这是最后一只了。\n它还是热的，\n所以我就在窗边把它吃了，\n配一杯咖啡，还有窗外自行车的声音。\n我想过给你留一半。\n我没有。\n对不起。\n—— M',
    },
    'rome': {
        "theme": 'memory',
        "title": 'The Last Coin',
        "body": 'Dear, Unknown,\nAn old woman gave me a coin today.\nShe was sitting beside the fountain,\nwhile the water glittered with hundreds of other coins.\nShe told me it was the last one.\nI asked her what she meant.\n“The last coin,” she said.\nI asked what it was worth.\nShe smiled.\n“Nothing anymore.”\nThen she put it in my hand and walked away.\nI still have it.\n— M',
        "title_zh": '最后一枚硬币',
        "body_zh": '亲爱的陌生人：\n今天有位老太太给了我一枚硬币。\n她坐在喷泉边上，\n水里还闪着另外几百枚。\n她说这是最后一枚。\n我问她这话什么意思。\n“最后一枚硬币。”她说。\n我问它值多少。\n她笑了。\n“已经什么都不值了。”\n然后她把它放进我手里，走了。\n我还留着。\n—— M',
    },
    'newyork': {
        "theme": 'leaving',
        "title": 'The Last Lonely Person',
        "body": "Dear, Unknown,\nI met a man in a diner last night.\nHe was sitting alone by the window,\nwatching the yellow cabs pass by.\nWe talked until they started closing.\nBefore I left, I asked why he came there every night.\nHe said,\n“So I don't have to be alone.”\nI thought that was strange.\nHe was alone the whole time.\n— M",
        "title_zh": '最后一个孤独的人',
        "body_zh": '亲爱的陌生人：\n昨天晚上我在一家小餐馆遇到一个人。\n他一个人坐在窗边，\n看着黄色的出租车开过去。\n我们一直聊到店里开始打烊。\n临走前我问他，为什么每天晚上都来这儿。\n他说：\n“这样我就不用一个人了。”\n我觉得这话很奇怪。\n他明明一直都是一个人。\n—— M',
    },
    'london': {
        "theme": 'kindness',
        "title": 'The Last Postcard',
        "body": "Dear, Unknown,\nLondon has been grey for days.\nThe sky never seems to change.\nEven the afternoons feel like evenings.\nI haven't heard from you in a long time.\nI used to think you were busy.\nThen I thought maybe you didn't want to write back.\nToday, I don't feel like guessing anymore.\nSo I think this will be the last postcard I send you.\nI hope you're well.\n— M",
        "title_zh": '最后一张明信片',
        "body_zh": '亲爱的陌生人：\n伦敦已经灰了好几天。\n天空好像从来不变。\n连下午都像傍晚。\n我很久没有收到你的消息了。\n以前我以为你只是忙。\n后来我想，也许你不想回信。\n今天，我不想再猜了。\n所以我想，这大概是我寄给你的最后一张明信片。\n希望你一切都好。\n—— M',
    },

    # Season Two answers Season One letter for letter: the blossom that is not
    # there, the pastry nobody makes, the coin that cannot be spent, the person
    # alone who is not lonely. The titles below are placeholders in the shape
    # of that pattern.
    'kyoto': {
        "theme": 'waiting',
        "title": 'No Cherry Blossoms',
        "title_zh": '没有樱花',
        "body": "Dear, Unknown,\nI came to Kyoto for the cherry blossoms.\nLast year, I remember them in Tokyo.\nThe crowds, the cameras,\nthe pink everywhere.\nBut Kyoto feels like an ordinary day.\nNo crowds.\nNo blossoms.\nEven the little Hello Kitty in the shop window\nis black now.\nI asked the girl behind the counter why.\nShe laughed.\n“Black is in this year.”\nI suppose that's a good enough reason.\n— M",
        "body_zh": '亲爱的陌生人：\n我为了樱花来京都。\n去年，我记得东京的樱花。\n人群，相机，\n到处都是粉色。\n但京都像是平常的一天。\n没有人群。\n没有花。\n连店铺橱窗里那只小 Hello Kitty\n现在都是黑色的。\n我问柜台后面的女孩为什么。\n她笑了。\n“今年流行黑色。”\n我想这理由也够了。\n—— M',
    },
    'sanfrancisco': {
        "theme": 'missing it',
        "title": "They Don't Make Those",
        "title_zh": '他们不做那个',
        "body": "Dear, Unknown,\nI found a little bakery this morning.\nI asked for a croissant.\nThe baker looked at me strangely.\n“We don't make those.”\nApparently, everyone here prefers sourdough now.\nI told him I didn't like sourdough.\nYou never did either.\nYou always said it was too heavy,\nand ordered a croissant instead.\nI asked if he knew where I could find one.\nHe said I was probably thinking of something else.\nMaybe I am.\nI left without one.\n— M",
        "body_zh": '亲爱的陌生人：\n今天早上我找到一家很小的面包店。\n我要了一只可颂。\n面包师奇怪地看着我。\n“我们不做那个。”\n好像这里的人现在都更喜欢酸面包。\n我告诉他我不喜欢酸面包。\n你以前也不喜欢。\n你总说那个太沉了，\n然后点一只可颂。\n我问他知不知道哪里能买到。\n他说我大概是记错了别的东西。\n也许我是记错了。\n我什么都没买就走了。\n—— M',
    },
    'istanbul': {
        "theme": 'memory',
        "title": 'Not Anymore',
        "title_zh": '已经不是了',
        "body": "Dear, Unknown,\nI tried to use the coin today.\nThe cashier looked at it\nas if I had handed him a button.\n“Sorry,” he said.\n“We don't take those.”\nI told him it was money.\nHe smiled.\n“Not anymore.”\nEveryone pays with their phones now.\nI suppose he's right.\nI put the coin back in my pocket.\nIt feels strange to carry something\neveryone has forgotten how to use.\n— M",
        "body_zh": '亲爱的陌生人：\n今天我想把那枚硬币用掉。\n收银员看着它，\n好像我递给他的是一颗纽扣。\n“抱歉，”他说，\n“我们不收这个。”\n我说这是钱。\n他笑了。\n“已经不是了。”\n现在大家都用手机付钱。\n我想他是对的。\n我把硬币放回口袋。\n带着一件所有人都不会用了的东西，\n感觉很奇怪。\n—— M',
    },
    'reykjavik': {
        "theme": 'leaving',
        "title": 'Alone, Not Lonely',
        "title_zh": '一个人，但不孤独',
        "body": "Dear, Unknown,\nI met someone today who lives alone.\nShe told me she likes it that way.\nI asked if she ever gets lonely.\nShe looked confused.\n“Why would I?”\nShe said she has books,\nmusic,\nthe sea,\nand plenty of things to do.\nI didn't know what to say.\nMaybe she's right.\nMaybe being alone\nisn't the same as being lonely.\nI still miss you.\n— M",
        "body_zh": '亲爱的陌生人：\n今天我遇到一个独自生活的人。\n她说她喜欢这样。\n我问她会不会觉得孤独。\n她一脸困惑。\n“我为什么会孤独？”\n她说她有书，\n有音乐，\n有海，\n还有很多事情可以做。\n我不知道该说什么。\n也许她是对的。\n也许一个人\n和孤独并不是一回事。\n我还是想你。\n—— M',
    },
}

SEASONS = [
    {
        "id": 's1',
        "number": 1,
        "title": 'The Last Ones',
        "title_zh": '最后的那些',
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
        "title_zh": '不存在的颜色',
        "cities": ['kyoto', 'sanfrancisco', 'istanbul', 'reykjavik', 'bermuda'],
        # Only the first season opens with a letter.
    },
]


# Cell states for the solver. EMPTY must be falsy: the "grid is entirely empty"
# check relies on it.
# ---------------------------------------------------------------------------
# The solver
#
# Cells hold a colour: 0 is empty, 1..n index the puzzle's palette. A black and
# white grid is the one-colour case, which is why there is no separate path for
# it — `#` in the art means colour one.
#
# The rule that makes colour puzzles their own thing, and the only place this
# differs from an ordinary line solver: two runs of the SAME colour need at
# least one blank between them, two runs of DIFFERENT colours may touch. That
# removes a great many of the easy deductions, so a colour grid that looks
# gentle can quietly require guessing — which is the whole reason this file
# refuses to ship one.

EMPTY = 0


def value_of(ch):
    """One art character to one cell value."""
    if ch == "#":
        return 1
    if ch.isdigit() and ch != "0":
        return int(ch)
    return EMPTY


def clues(line):
    """Runs of a line as (length, colour). Touching colours are separate runs
    with no gap between them, which is exactly what the player must work out."""
    out = []
    run, colour = 0, EMPTY
    for v in line:
        if v == colour and v != EMPTY:
            run += 1
            continue
        if run:
            out.append((run, colour))
        colour = v
        run = 1 if v != EMPTY else 0
    if run:
        out.append((run, colour))
    return out


def _minimum_span(clue, idx):
    """Fewest cells the runs from `idx` onward can occupy."""
    need = sum(c[0] for c in clue[idx:])
    for j in range(idx, len(clue) - 1):
        if clue[j][1] == clue[j + 1][1]:
            need += 1
    return need


@lru_cache(maxsize=None)
def placements(length, clue):
    """Every way to lay `clue` into a line of `length`, as tuples of values."""
    if not clue:
        return ((EMPTY,) * length,)
    out = []
    n = len(clue)

    def build(idx, pos, acc):
        if idx == n:
            out.append(tuple(acc + [EMPTY] * (length - pos)))
            return
        run_len, colour = clue[idx]
        need = _minimum_span(clue, idx)
        for start in range(pos, length - need + 1):
            row = acc + [EMPTY] * (start - pos) + [colour] * run_len
            nxt = start + run_len
            # A blank is forced only between runs that share a colour.
            if idx < n - 1 and clue[idx + 1][1] == colour:
                row = row + [EMPTY]
                nxt += 1
            build(idx + 1, nxt, row)

    build(0, 0, [])
    return tuple(out)


def solve_line(length, clue, domains):
    """Every placement still possible, merged. Returns new domains, or None if
    the line has become impossible."""
    merged = None
    for cand in placements(length, tuple(clue)):
        ok = True
        for i in range(length):
            if not domains[i] >> cand[i] & 1:
                ok = False
                break
        if not ok:
            continue
        bits = [1 << v for v in cand]
        if merged is None:
            merged = bits
        else:
            for i in range(length):
                merged[i] |= bits[i]
    return merged


def line_solve(row_clues, col_clues, h, w, colours):
    """Constraint propagation, one line at a time, until nothing more moves.

    Deliberately no search: a grid that cannot be finished this way is one that
    needs a guess somewhere, and that is exactly what must not ship.
    """
    full = (1 << (colours + 1)) - 1
    grid = [[full] * w for _ in range(h)]
    changed = True
    while changed:
        changed = False
        for r in range(h):
            merged = solve_line(w, row_clues[r], grid[r])
            if merged is None:
                return None, False
            if merged != grid[r]:
                grid[r] = merged
                changed = True
        for c in range(w):
            col = [grid[r][c] for r in range(h)]
            merged = solve_line(h, col_clues[c], col)
            if merged is None:
                return None, False
            if merged != col:
                for r in range(h):
                    grid[r][c] = merged[r]
                changed = True
    solved = all(bin(v).count("1") == 1 for row in grid for v in row)
    return grid, solved


def validate(puzzle):
    art = puzzle["art"]
    h = len(art)
    w = len(art[0])
    errs = []
    allowed = set("#.123456789")
    for i, row in enumerate(art):
        if len(row) != w:
            errs.append("row %d is %d wide, expected %d" % (i, len(row), w))
        bad = set(row) - allowed
        if bad:
            errs.append("row %d has bad chars %r" % (i, sorted(bad)))
    if errs:
        return errs, None

    grid = [[value_of(ch) for ch in row] for row in art]
    colours = max((v for row in grid for v in row), default=0)
    if colours == 0:
        return ["grid is entirely empty"], None

    declared = len(puzzle.get("palette") or []) or 1
    if colours > declared:
        errs.append("uses colour %d but the palette has %d" % (colours, declared))
        return errs, None

    rc = [clues(row) for row in grid]
    cc = [clues([grid[r][c] for r in range(h)]) for c in range(w)]

    solution, solved = line_solve(rc, cc, h, w, colours)
    if solution is None:
        errs.append("contradictory clues")
    elif not solved:
        unknown = sum(1 for row in solution for v in row if bin(v).count("1") > 1)
        errs.append("NOT line-solvable: %d cells need guessing (solution may not be unique)" % unknown)
    else:
        found = [[v.bit_length() - 1 for v in row] for row in solution]
        if found != grid:
            errs.append("solver found a different grid - solution is not unique")
    return errs, {"rows": rc, "cols": cc, "colours": colours}


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
                "palette": p.get("palette", []),
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
            "title": T(entry.get("title", ""), entry.get("title_zh", "")),
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
        sc["title"] = T(season["title"], season.get("title_zh", ""))
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
