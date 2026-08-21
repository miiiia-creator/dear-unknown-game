extends Node
## Colour + font system. Autoloaded as `Pal`.
##
## Two moods: "paper" (daytime travel journal) and "evening" (lamp-lit).
## Everything in the game asks Pal for colour so a single toggle re-skins the
## whole app.

signal theme_changed
signal locale_changed

## Languages the game offers, in menu order.
const LOCALES := [
	{"code": "en", "label": "English"},
	{"code": "zh_CN", "label": "中文"},
]

const PAPER := {
	# A grey-taupe with a green bias rather than a cream. Warm paper made every
	# screen look homely, and it fought the paintings — a Hopper night and a
	# Caravaggio have nowhere to sit on cream. This ground recedes instead.
	"bg": "#DEDCD6",
	"panel": "#E8E6E1",
	"panel_alt": "#D5D3CC",
	"ink": "#1C1D1B",
	"ink_soft": "#6B6E68",
	"ink_faint": "#9B9E97",
	"line": "#C6C5BE",
	"line_strong": "#A8A79F",
	"accent": "#47584E",
	"accent_soft": "#C3CCC6",
	"gold": "#8A7A4E",
	"good": "#4E6A58",
	"cell": "#1C1D1B",
	"shadow": "#00000012",
}

const EVENING := {
	"bg": "#141513",
	"panel": "#1C1E1B",
	"panel_alt": "#232520",
	"ink": "#E2E1DA",
	"ink_soft": "#9A9D95",
	"ink_faint": "#63665F",
	"line": "#2E312D",
	"line_strong": "#4A4E48",
	"accent": "#8FA79A",
	"accent_soft": "#2A322C",
	"gold": "#C0AA72",
	"good": "#8FA79A",
	"cell": "#E2E1DA",
	"shadow": "#00000045",
}

var mood: String = "paper"

var ui_font: Font
var mono_font: Font

## The face M's letters are written in. Everything else on the card — the
## postmark, the country on the stamp — is printed, and uses `ui_font`.
var letter_font: Font


func _ready() -> void:
	_build_fonts()


func _build_fonts() -> void:
	# Bundled rather than borrowed from the OS. System faces differ per platform
	# — iOS has no glyph for the box and cross marks the toolbar used, so they
	# arrived as tofu on a phone while looking fine on a Mac. Shipping the font
	# makes every platform draw the same thing, and gives the Chinese build
	# somewhere to hang its own face later.
	#
	# IBM Plex, SIL Open Font License 1.1 (see assets/fonts/OFL.txt).
	# Chinese hangs off the Latin faces as a fallback rather than replacing them:
	# a mixed line ("Season One — 第一季") then sets in one pass, and Latin keeps
	# Plex's shapes instead of the CJK face's.
	#
	# Two Chinese faces, because the game sets two kinds of Chinese.
	#
	# The letters are somebody's handwriting: 霞鹜文楷 (LXGW WenKai), a 楷体, where
	# the strokes enter and leave the way a brush does. Everything else is
	# printed — the interface, the postmarks, the country on a stamp, the clue
	# numbers — and gets 思源宋体 (Noto Serif SC), because that is what print
	# looks like. Both OFL 1.1, like Plex.
	#
	# One face for both was wrong in each direction: a gothic set the letters in
	# the same voice as the buttons, and the 楷体 set the buttons in M's hand.
	#
	# Each is subset to the characters the game actually uses — the full pair is
	# 35 MB, several times the entire web build. Re-run tools/subset_font.py
	# after changing any Chinese copy.
	var printed := _load("res://assets/fonts/NotoSerifSC-subset.otf")
	var written := _load("res://assets/fonts/LXGWWenKai-subset.ttf")

	ui_font = _load("res://assets/fonts/IBMPlexSans.ttf")
	mono_font = _load("res://assets/fonts/IBMPlexMono-Regular.ttf")
	# A second, separate copy of the Latin face. `load()` hands back the one
	# instance it has cached for a path, so loading Plex twice gave the same
	# object twice — and setting a fallback on "one of them" set it on both.
	# The interface and the letters ended up in whichever face was assigned
	# last, which is how the 楷体 never reached a postcard.
	letter_font = _load("res://assets/fonts/IBMPlexSans.ttf", true)
	for f in [ui_font, mono_font]:
		if f is FontFile and printed != null:
			(f as FontFile).fallbacks = [printed]
	if letter_font is FontFile and written != null:
		(letter_font as FontFile).fallbacks = [written]


## How far apart two colours have to be before one can be read on the other.
## Tuned for the clue numbers, which are the smallest coloured thing the game
## draws: below this the pale end of a palette simply is not there.
const READABLE := 2.4


## An ink is picked for a filled cell, where it sits in a solid block with its
## neighbours around it. The same ink as a clue number is a few thin strokes on
## the open page, and a pale one — Bermuda's cloud, Reykjavík's gold — vanished.
##
## Take the value away from the page and put the chroma back as you go, so what
## is left is a deeper version of the same colour rather than a greyer one.
##
## Walking toward black instead — which is what this did first — is the same
## thing as turning the value down with the saturation left alone, and a dark
## gold is simply brown. San Francisco has two inks, a brown and a gold, and
## they arrived at the same brown: a two-colour puzzle whose clues were one
## colour. Deepening with the saturation rising keeps gold gold.
##
## Mirrored for the evening, where the page is dark and the way out is up: value
## rises and chroma comes off, which is what a tint is.
func legible(ink: Color, page: Color = c("bg"), want: float = READABLE) -> Color:
	var lighten := page.get_luminance() <= 0.5
	var out := ink
	for _step in 24:
		if contrast(out, page) >= want:
			break
		if lighten:
			out = Color.from_hsv(out.h, maxf(0.0, out.s * 0.94 - 0.02),
					minf(1.0, out.v * 1.06 + 0.02), ink.a)
		else:
			out = Color.from_hsv(out.h, minf(1.0, out.s * 1.10 + 0.02),
					maxf(0.0, out.v * 0.94), ink.a)
	out.a = ink.a
	return out


func contrast(a: Color, b: Color) -> float:
	var la := a.get_luminance()
	var lb := b.get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _load(path: String, fresh: bool = false) -> Font:
	var f: Font = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) \
			if fresh else load(path)
	if f == null:
		push_warning("Missing bundled font %s — falling back to the system face." % path)
		var fallback := SystemFont.new()
		fallback.font_names = PackedStringArray(["Helvetica Neue", "Segoe UI", "sans-serif"])
		fallback.allow_system_fallback = true
		return fallback
	if f is FontFile:
		# Crisp small type: the interface lives at 12-16px and hinting matters
		# more there than any subpixel smoothing does.
		(f as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		(f as FontFile).hinting = TextServer.HINTING_LIGHT
		(f as FontFile).subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


## Switch language. Content resolves through GameData.text(); interface strings
## go through the translation table, so both follow from this one call.
func set_locale(code: String) -> void:
	if TranslationServer.get_locale() == code:
		return
	TranslationServer.set_locale(code)
	locale_changed.emit()


func locale_label(code: String) -> String:
	for l in LOCALES:
		if l["code"] == code:
			return str(l["label"])
	return code


func set_mood(value: String) -> void:
	if value == mood:
		return
	mood = value
	theme_changed.emit()


func toggle_mood() -> void:
	set_mood("evening" if mood == "paper" else "paper")


func c(key: String) -> Color:
	var table: Dictionary = PAPER if mood == "paper" else EVENING
	return Color(table.get(key, "#FF00FF"))


## Blend a colour towards the current background — handy for soft fills.
func fade(key: String, amount: float) -> Color:
	return c(key).lerp(c("bg"), amount)
