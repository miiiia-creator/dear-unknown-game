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
	# Plex's shapes instead of Noto's.
	#
	# The CJK face is subset to the characters the game actually uses — the full
	# one is 17 MB, which is three times the entire web build. Re-run
	# tools/subset_font.py after changing any Chinese copy.
	var cjk := _load("res://assets/fonts/NotoSansSC-subset.ttf")

	ui_font = _load("res://assets/fonts/IBMPlexSans.ttf")
	mono_font = _load("res://assets/fonts/IBMPlexMono-Regular.ttf")
	for f in [ui_font, mono_font]:
		if f is FontFile and cjk != null:
			(f as FontFile).fallbacks = [cjk]


func _load(path: String) -> Font:
	var f: Font = load(path)
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
